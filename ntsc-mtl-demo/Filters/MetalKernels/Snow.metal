//
//  Snow.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-05.
//

#include "ClampFunctions.metal"
#include <metal_stdlib>
using namespace metal;

constant half PI_16 = half(3.140625);

kernel void snow
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant half &intensity [[buffer(0)]],
 constant half &anisotropy [[buffer(1)]],
 constant half &bandwidthScale [[buffer(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    
    half4 inputPixel = inputTexture.read(gid);
    half4 randomPixel = randomTexture.read(gid);
    half rand1 = randomPixel.x;
    half rand2 = randomPixel.y;
    half rand3 = randomPixel.z;
    
//    /*
//     let logistic_factor = ((rng.gen::<f64>() - intensity)
//         / (intensity * (1.0 - intensity) * (1.0 - anisotropy)))
//         .exp();
//     */
//    half logisticFactor = exp((rand1 - intensity) / (intensity * (1.0 - intensity) * (1.0 - anisotropy)));
//    
//    /*
//     let mut line_snow_intensity: f64 =
//         anisotropy / (1.0 + logistic_factor) + intensity * (1.0 - anisotropy);
//    */
//    half lineSnowIntensity = (anisotropy / (1.0 + logisticFactor)) + (intensity * (1.0 - anisotropy));
//    lineSnowIntensity *= 0.125;
//    
//    lineSnowIntensity = clamp(lineSnowIntensity, half(0.0), half(1.0));
//    if (lineSnowIntensity <= 0.0) {
//        outputTexture.write(inputPixel, gid);
//        return;
//    }
//    
//    // Say transientLen is 30
//    half transientLen = mix(half(8.0), half(64.0), rand2) * bandwidthScale;
//    // floor is 90
//    half transientFreqFloor = transientLen * half(3.0);
//    // ceil is 150
//    half transientFreqCeil = transientLen * half(5.0);
//    // freq is 120
//    float transientFreq = mix(transientFreqFloor, transientFreqCeil, rand3);
//    // {0, 1000}
//    half x = half(gid.x);
//    // 3.14 * 0 *...) --> cos(0) is 1 (I think)
//    /*
//     row[i] += ((x * PI) / transient_freq).cos()
//     domain is -1 to 1
//     */
//    half cosTerm = cos((PI_16 * x) / transientFreq);
//    /*
//     * (1.0 - x / transient_len).powi(2)
//     * transient_rng.gen_range(-1.0..2.0);
//     */
//    half transientLenTerm = pow((half(1.0) - x)/ transientLen, 2);
//    
//    half finalTerm = mix(half(-1.0), half(2.0), rand3);
//    
//    /*
//     row[i] += ((x * PI) / transient_freq).cos()
//         * (1.0 - x / transient_len).powi(2)
//         * transient_rng.gen_range(-1.0..2.0);
//     
//     cosTerm * transientLenTerm * finalTerm
//     */
//    half mod = cosTerm * transientLenTerm * finalTerm;
//    half4 modPixel = inputPixel;
//    modPixel.x += (mod * half(1000));
    half4 modPixel = (inputPixel + randomPixel) * 0.5;
    outputTexture.write(modPixel, gid);
}
