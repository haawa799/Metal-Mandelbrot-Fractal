//
//  Square.swift
//  Mandelbrot
//
//  Created by Andriy K. on 2/4/16.
//  Copyright © 2016 Andriy K. All rights reserved.
//

import Foundation
import MetalKit

struct Vertex {
  let x, y, z : Float
}

struct Square {
  
  var vertexBuffer: MTLBuffer?
  var vertexCount = 0
  
  init(device: MTLDevice) {
    
    let A = Vertex(x: -1.0, y: -1.0, z: 0)
    let B = Vertex(x: -1.0, y: 1.0, z: 0)
    let C = Vertex(x: 1.0, y: -1.0, z: 0)
    let D = Vertex(x: 1.0, y: 1.0, z: 0)
    
    var vertices = [A, B, C, B, D, C]
    vertexCount = vertices.count
    vertexBuffer = device.makeBuffer(bytes: &vertices,
                                     length: vertices.count * MemoryLayout<Vertex>.size,
                                     options: MTLResourceOptions())
  }
  
  func defaultSampler(_ device: MTLDevice) -> MTLSamplerState {
    let sampler = MTLSamplerDescriptor()
    sampler.minFilter             = MTLSamplerMinMagFilter.nearest
    sampler.magFilter             = MTLSamplerMinMagFilter.nearest
    sampler.mipFilter             = MTLSamplerMipFilter.nearest
    sampler.maxAnisotropy         = 1
    sampler.sAddressMode          = MTLSamplerAddressMode.clampToEdge
    sampler.tAddressMode          = MTLSamplerAddressMode.clampToEdge
    sampler.rAddressMode          = MTLSamplerAddressMode.clampToEdge
    sampler.normalizedCoordinates = true
    sampler.lodMinClamp           = 0
    sampler.lodMaxClamp           = Float.greatestFiniteMagnitude
    return device.makeSamplerState(descriptor: sampler)!
  }
}
