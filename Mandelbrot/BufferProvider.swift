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
  
  fileprivate var raw: [Float] {
    return [scale, translation.x, translation.y, maxNumberOfiterations, aspectRatio, 0, 0, 0]
  }
  
  static var size = MemoryLayout<Float>.size * 8
}


/// I use class, to have deinit() for semaphores cleanup
class BufferProvider {
  
  // General values
  static let floatSize = MemoryLayout<Float>.size
  static var bufferSize = Uniform.size
  
  // Reuse related
  fileprivate(set) var indexOfAvaliableBuffer = 0
  fileprivate(set) var numberOfInflightBuffers: Int
  fileprivate var buffers:[MTLBuffer]
  fileprivate(set) var avaliableResourcesSemaphore:DispatchSemaphore
  
  init(inFlightBuffers: Int, device: MTLDevice) {
    
    avaliableResourcesSemaphore = DispatchSemaphore(value: inFlightBuffers)
    
    numberOfInflightBuffers = inFlightBuffers
    buffers = [MTLBuffer]()
    
    for _ in 0 ..< inFlightBuffers {
      let buffer = device.makeBuffer(length: BufferProvider.bufferSize, options: MTLResourceOptions())
      buffer.label = "Uniform buffer"
      buffers.append(buffer)
    }
  }
  
  deinit{
    for _ in 0...numberOfInflightBuffers{
      avaliableResourcesSemaphore.signal()
    }
  }
  
  func nextBufferWithData(_ uniform: Uniform) -> MTLBuffer {
    
    // Cycle through buffers
    let uniformBuffer = self.buffers[indexOfAvaliableBuffer]
    indexOfAvaliableBuffer += 1
    if indexOfAvaliableBuffer == numberOfInflightBuffers {
      indexOfAvaliableBuffer = 0
    }
    
    memcpy(uniformBuffer.contents(), uniform.raw, Uniform.size)
    return uniformBuffer
  }
  
}
