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
    vertexBuffer = device.newBufferWithBytes(&vertices, length: vertices.count * sizeof(Vertex), options: MTLResourceOptions.CPUCacheModeDefaultCache)
  }
  
  func defaultSampler(device: MTLDevice) -> MTLSamplerState
  {
    let pSamplerDescriptor:MTLSamplerDescriptor? = MTLSamplerDescriptor();
    
    if let sampler = pSamplerDescriptor
    {
      sampler.minFilter             = MTLSamplerMinMagFilter.Nearest
      sampler.magFilter             = MTLSamplerMinMagFilter.Nearest
      sampler.mipFilter             = MTLSamplerMipFilter.Nearest
      sampler.maxAnisotropy         = 1
      sampler.sAddressMode          = MTLSamplerAddressMode.ClampToEdge
      sampler.tAddressMode          = MTLSamplerAddressMode.ClampToEdge
      sampler.rAddressMode          = MTLSamplerAddressMode.ClampToEdge
      sampler.normalizedCoordinates = true
      sampler.lodMinClamp           = 0
      sampler.lodMaxClamp           = FLT_MAX
    }
    else
    {
      print(">> ERROR: Failed creating a sampler descriptor!")
    }
    return device.newSamplerStateWithDescriptor(pSamplerDescriptor!)
  }
  
}