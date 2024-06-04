//
//  YIQChannel.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-04.
//

#include <metal_stdlib>
using namespace metal;

typedef enum: uint {
    YIQChannelY = 0,
    YIQChannelI = 1,
    YIQChannelQ = 2,
} YIQChannel;
