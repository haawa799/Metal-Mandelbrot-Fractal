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
  private var device: MTLDevice!
  private var commandQ: MTLCommandQueue!
  private var pipelineState: MTLRenderPipelineState!
  private var depthStencilState: MTLDepthStencilState!
  private var paletteTexture: MTLTexture!
  private var samplerState: MTLSamplerState!
  private var uniformBufferProvider: BufferProvider!
  private var mandelbrotSceneUniform = Uniform()
  
  // Flags to control draw calls
  private var needsRedraw = true
  var forceAlwaysDraw = false
  
  // Object to render
  private var square: Square!
  
  
  // Handles to move and zoom
  private var oldZoom: Float = 205614.0//1.0
  private var shiftX: Float = 0.858308//0
  private var shiftY: Float = 0.240118//0
  
  
  @IBOutlet var metalView: MTKView! {
    didSet {
      metalView.device = device
      metalView.delegate = self
      metalView.preferredFramesPerSecond = 60
      metalView.depthStencilPixelFormat = MTLPixelFormat.Depth32Float_Stencil8
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupMetal()
    
    guard let defaultLibrary = device.newDefaultLibrary() else {
      assert(false)
      return
    }
    let vertexProgram = defaultLibrary.newFunctionWithName("vertexShader")!
    let fragmentProgram = defaultLibrary.newFunctionWithName("fragmentShader")!
    
    let metalVertexDescriptor = myVertexDescriptor()
    
    pipelineState = compiledPipelineStateFrom(vertexShader: vertexProgram, fragmentShader: fragmentProgram, vertexDescriptor: metalVertexDescriptor)
    depthStencilState = compiledDepthState()
  }
  
  
  func setupMetal() {
    device = MTLCreateSystemDefaultDevice()
    metalView.device = device
    commandQ = device.newCommandQueue()
    square = Square(device: device)
    
    let textureLoader = MTKTextureLoader(device: device)
    let path = NSBundle.mainBundle().pathForResource("pal", ofType: "png")!
    let data = NSData(contentsOfFile: path)!
    
    paletteTexture = try! textureLoader.newTextureWithData(data, options: nil)
    samplerState = square.defaultSampler(device)
    uniformBufferProvider = BufferProvider(inFlightBuffers: 3, device: device)
  }
  
  func myVertexDescriptor() -> MTLVertexDescriptor {
    let metalVertexDescriptor = MTLVertexDescriptor()
    if let attribute = metalVertexDescriptor.attributes[0] {
      attribute.format = MTLVertexFormat.Float3
      attribute.offset = 0
      attribute.bufferIndex = 0
    }
    if let layout = metalVertexDescriptor.layouts[0] {  // this zero correspons to  buffer index
      layout.stride = sizeof(Float) * (3)
    }
    return metalVertexDescriptor
  }
  
}


// MARK: - Compiled states
extension MandelbrotViewController {
  
  /// Compile vertex, fragment shaders and vertex descriptor into pipeline state object
  func compiledPipelineStateFrom(vertexShader vertexShader: MTLFunction, fragmentShader: MTLFunction, vertexDescriptor: MTLVertexDescriptor) -> MTLRenderPipelineState? {
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
    pipelineStateDescriptor.vertexFunction = vertexShader
    pipelineStateDescriptor.fragmentFunction = fragmentShader
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
    pipelineStateDescriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
    pipelineStateDescriptor.stencilAttachmentPixelFormat = metalView.depthStencilPixelFormat
    
    let compiledState = try! device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
    return compiledState
  }
  
  /// Compile depth/stencil descriptor into state object
  /// We don't really need depth check for this example but it's a good thing to have
  func compiledDepthState() -> MTLDepthStencilState {
    let depthStencilDesc = MTLDepthStencilDescriptor()
    depthStencilDesc.depthCompareFunction = MTLCompareFunction.Less
    depthStencilDesc.depthWriteEnabled = true
    
    return device.newDepthStencilStateWithDescriptor(depthStencilDesc)
  }
  
}


// MARK: - Zoom & Move
extension MandelbrotViewController {
  
  override func mouseDragged(theEvent: NSEvent) {
    super.mouseDragged(theEvent)
    
    let xDelta = Float(theEvent.deltaX/self.view.bounds.width)
    let yDelta = Float(theEvent.deltaY/self.view.bounds.height)
    
    shiftX += xDelta / oldZoom
    shiftY -= yDelta / oldZoom
    
    mandelbrotSceneUniform.translation = (shiftX, shiftY)
    needsRedraw = true
  }
  
  @IBAction func zoom(sender: NSMagnificationGestureRecognizer) {
    
    let zoom = Float(sender.magnification)
    let zoomMultiplier = Float(max(Int(oldZoom / 100),1)) // to speed up zooming the deeper you go
    
    oldZoom += zoom * zoomMultiplier
    oldZoom = max(1, oldZoom)
    mandelbrotSceneUniform.scale = 1 / oldZoom
    needsRedraw = true
  }
}

extension MandelbrotViewController: MTKViewDelegate {
  
  func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
    mandelbrotSceneUniform.aspectRatio = Float(size.width / size.height)
    needsRedraw = true
  }
  
  func drawInMTKView(view: MTKView) {
    
    guard (needsRedraw == true || forceAlwaysDraw == true) else { return }
    guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
    guard let drawable = view.currentDrawable else { return }
    
    renderPassDescriptor.colorAttachments[0].loadAction = .Clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.Store
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    
    let commandBuffer = commandQ.commandBuffer()
    
    let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setCullMode(MTLCullMode.None)
    
    if let squareBuffer = square?.vertexBuffer {
      renderEncoder.setVertexBuffer(squareBuffer, offset: 0, atIndex: 0)
    }
    
    let uniformBuffer = uniformBufferProvider.nextBufferWithData(mandelbrotSceneUniform)
    renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
    renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, atIndex: 0)
    
    renderEncoder.setFragmentTexture(paletteTexture, atIndex: 0)
    renderEncoder.setFragmentSamplerState(samplerState, atIndex: 0)
    
    renderEncoder.drawPrimitives(MTLPrimitiveType.Triangle, vertexStart: 0, vertexCount: 6)
    
    renderEncoder.endEncoding()
    commandBuffer.presentDrawable(drawable)
    commandBuffer.commit()
    
    needsRedraw = false
  }
  
}