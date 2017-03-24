//
//  ViewController.swift
//  Mandelbrot
//
//  Created by Andriy K. on 2/4/16.
//  Copyright © 2016 Andriy K. All rights reserved.
//

import Cocoa
import MetalKit

class MandelbrotViewController: NSViewController {
  
  // Metal related properties
  fileprivate var device: MTLDevice!
  fileprivate var commandQ: MTLCommandQueue!
  fileprivate var pipelineState: MTLRenderPipelineState!
  fileprivate var depthStencilState: MTLDepthStencilState!
  fileprivate var paletteTexture: MTLTexture!
  fileprivate var samplerState: MTLSamplerState!
  fileprivate var uniformBufferProvider: BufferProvider!
  fileprivate var mandelbrotSceneUniform = Uniform()
  
  // Flags to control draw calls
  fileprivate var needsRedraw = true
  var forceAlwaysDraw = false
  
  // Object to render
  fileprivate var square: Square!
  
  
  // Handles to move and zoom
  fileprivate var oldZoom: Float = 1.0
  fileprivate var shiftX: Float = 0
  fileprivate var shiftY: Float = 0
  
  
  @IBOutlet var metalView: MTKView! {
    didSet {
      metalView.device = device
      metalView.delegate = self
      metalView.preferredFramesPerSecond = 60
      metalView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupMetal()
    
    guard let defaultLibrary = device.newDefaultLibrary() else {
      assert(false)
      return
    }
    let vertexProgram = defaultLibrary.makeFunction(name: "vertexShader")!
    let fragmentProgram = defaultLibrary.makeFunction(name: "fragmentShader")!
    
    let metalVertexDescriptor = myVertexDescriptor()
    
    pipelineState = compiledPipelineStateFrom(vertexShader: vertexProgram, fragmentShader: fragmentProgram, vertexDescriptor: metalVertexDescriptor)
    depthStencilState = compiledDepthState()
  }
  
  
  func setupMetal() {
    device = MTLCreateSystemDefaultDevice()
    metalView.device = device
    commandQ = device.makeCommandQueue()
    square = Square(device: device)
    
    let textureLoader = MTKTextureLoader(device: device)
    let path = Bundle.main.path(forResource: "pal", ofType: "png")!
    let data = try! Data(contentsOf: URL(fileURLWithPath: path))
    
    paletteTexture = try! textureLoader.newTexture(with: data, options: nil)
    samplerState = square.defaultSampler(device)
    uniformBufferProvider = BufferProvider(inFlightBuffers: 3, device: device)
  }
  
  func myVertexDescriptor() -> MTLVertexDescriptor {
    let metalVertexDescriptor = MTLVertexDescriptor()
    if let attribute = metalVertexDescriptor.attributes[0] {
      attribute.format = MTLVertexFormat.float3
      attribute.offset = 0
      attribute.bufferIndex = 0
    }
    if let layout = metalVertexDescriptor.layouts[0] {  // this zero correspons to  buffer index
      layout.stride = MemoryLayout<Float>.size * (3)
    }
    return metalVertexDescriptor
  }
  
}


// MARK: - Compiled states
extension MandelbrotViewController {
  
  /// Compile vertex, fragment shaders and vertex descriptor into pipeline state object
  func compiledPipelineStateFrom(vertexShader: MTLFunction, fragmentShader: MTLFunction, vertexDescriptor: MTLVertexDescriptor) -> MTLRenderPipelineState? {
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
    pipelineStateDescriptor.vertexFunction = vertexShader
    pipelineStateDescriptor.fragmentFunction = fragmentShader
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
    pipelineStateDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
    pipelineStateDescriptor.stencilAttachmentPixelFormat = metalView.depthStencilPixelFormat
    
    let compiledState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    return compiledState
  }
  
  /// Compile depth/stencil descriptor into state object
  /// We don't really need depth check for this example but it's a good thing to have
  func compiledDepthState() -> MTLDepthStencilState {
    let depthStencilDesc = MTLDepthStencilDescriptor()
    depthStencilDesc.depthCompareFunction = MTLCompareFunction.less
    depthStencilDesc.isDepthWriteEnabled = true
    
    return device.makeDepthStencilState(descriptor: depthStencilDesc)
  }
  
}


// MARK: - Zoom & Move
extension MandelbrotViewController {
  
  override func mouseDragged(with theEvent: NSEvent) {
    super.mouseDragged(with: theEvent)
    
    let xDelta = Float(theEvent.deltaX/self.view.bounds.width)
    let yDelta = Float(theEvent.deltaY/self.view.bounds.height)
    
    shiftX += xDelta / oldZoom
    shiftY -= yDelta / oldZoom
    
    mandelbrotSceneUniform.translation = (shiftX, shiftY)
    needsRedraw = true
  }
  
  @IBAction func zoom(_ sender: NSMagnificationGestureRecognizer) {
    
    let zoom = Float(sender.magnification)
    let zoomMultiplier = Float(max(Int(oldZoom / 100),1)) // to speed up zooming the deeper you go
    
    oldZoom += zoom * zoomMultiplier
    oldZoom = max(1, oldZoom)
    mandelbrotSceneUniform.scale = 1 / oldZoom
    needsRedraw = true
  }
}

extension MandelbrotViewController: MTKViewDelegate {
  
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    mandelbrotSceneUniform.aspectRatio = Float(size.width / size.height)
    needsRedraw = true
  }
  
  func draw(in view: MTKView) {
    
    guard (needsRedraw == true || forceAlwaysDraw == true) else { return }
    guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
    guard let drawable = view.currentDrawable else { return }
    
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    
    let commandBuffer = commandQ.makeCommandBuffer()
    
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setCullMode(MTLCullMode.none)
    
    if let squareBuffer = square?.vertexBuffer {
      renderEncoder.setVertexBuffer(squareBuffer, offset: 0, at: 0)
    }
    
    let uniformBuffer = uniformBufferProvider.nextBufferWithData(mandelbrotSceneUniform)
    renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
    renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, at: 0)
    
    renderEncoder.setFragmentTexture(paletteTexture, at: 0)
    renderEncoder.setFragmentSamplerState(samplerState, at: 0)
    
    renderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 6)
    
    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
    
    needsRedraw = false
  }
  
}
