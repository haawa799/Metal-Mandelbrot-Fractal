//
//  BufferProvider.swift
//  Model_IO_OSX
//
//  Created by Andriy K. on 6/20/15.
//  Copyright © 2015 Andriy K. All rights reserved.
//

import Cocoa
import simd
import Accelerate

/// This class is responsible for providing a uniformBuffer which will be passed to vertex shader. It holds n buffers. In case n == 3 for frame0 it will give buffer0 for frame1 - buffer1 for frame2 - buffer2 for frame3 - buffer0 and so on. It's user responsibility to make sure that GPU is not using that buffer before use. For details refer to wwdc session 604 (18:00).

struct Uniform {
  var scale: Float = 1
  var translation: (x: Float, y: Float) = (0, 0)
  var maxNumberOfiterations: Float = 500
  var aspectRatio: Float = 1
  
  private var raw: [Float] {
    return [scale, translation.x, translation.y, maxNumberOfiterations, aspectRatio, 0, 0, 0]
  }
  
  static var size = sizeof(Float) * 8
}


/// I use class, to have deinit() for semaphores cleanup
class BufferProvider {
  
  // General values
  static let floatSize = sizeof(Float)
  static var bufferSize = Uniform.size
  
  // Reuse related
  private(set) var indexOfAvaliableBuffer = 0
  private(set) var numberOfInflightBuffers: Int
  private var buffers:[MTLBuffer]
  private(set) var avaliableResourcesSemaphore:dispatch_semaphore_t
  
  init(inFlightBuffers: Int, device: MTLDevice) {
    
    avaliableResourcesSemaphore = dispatch_semaphore_create(inFlightBuffers)
    
    numberOfInflightBuffers = inFlightBuffers
    buffers = [MTLBuffer]()
    for (var i = 0; i < inFlightBuffers; i++) {
      let buffer = device.newBufferWithLength(BufferProvider.bufferSize, options: MTLResourceOptions.CPUCacheModeDefaultCache)
      buffer.label = "Uniform buffer"
      buffers.append(buffer)
    }
  }
  
  deinit{
    for _ in 0...numberOfInflightBuffers{
      dispatch_semaphore_signal(avaliableResourcesSemaphore)
    }
  }
  
  func nextBufferWithData(uniform: Uniform) -> MTLBuffer {
    
    // Cycle through buffers
    let uniformBuffer = self.buffers[indexOfAvaliableBuffer++]
    if indexOfAvaliableBuffer == numberOfInflightBuffers {
      indexOfAvaliableBuffer = 0
    }
    
    memcpy(uniformBuffer.contents(), uniform.raw, Uniform.size)
    return uniformBuffer
  }
  
}
