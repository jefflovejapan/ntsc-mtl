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

half sampleGeometric
(
 half u,    // uniform random variable
 half p     // line snow intensity
 ) {
    return log(u) / log(p);
}

kernel void snow
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
// texture2d<half, access::read> snowIntensityTexture [[texture(2)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 constant half &bandwidthScale [[buffer(0)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    
    half4 inputPixel = inputTexture.read(gid);
    half4 randomPixel = randomTexture.read(gid);    // uniform random values
//    half snowIntensity = snowIntensityTexture.read(gid).x;
    
    // Already used x to calculate snow intensity
    half transientLenRnd = randomPixel.y;   // i
    half transientFreqRnd = randomPixel.z;  // q
    half finalTermRnd = randomPixel.w;      // alpha
    
    float transientLen = mix(8.0, 64.0, float(transientLenRnd)) * float(bandwidthScale);
    float transientFreq = mix(transientLen * 3.0, transientLen * 5.0, float(transientFreqRnd));
    
    float x = float(gid.x);
    // 3.14 * 0 *...) --> cos(0) is 1 (I think)
    /*
     row[i] += ((x * PI) / transient_freq).cos()
     domain is -1 to 1
     */
    float cosTerm = cos((M_PI_F * x) / transientFreq);
    /*
     * (1.0 - x / transient_len).powi(2)
     * transient_rng.gen_range(-1.0..2.0);
     */
    float transientLenTerm = pow(1.0 - (x / transientLen), 2);
    
    float finalTerm = mix(-1.0, 2.0, float(finalTermRnd));
    
    /*
     row[i] += ((x * PI) / transient_freq).cos()
         * (1.0 - x / transient_len).powi(2)
         * transient_rng.gen_range(-1.0..2.0);
     
     cosTerm * transientLenTerm * finalTerm
     */
    half mod = half(cosTerm * transientLenTerm * finalTerm);
    half4 modPixel = inputPixel;
    modPixel.x += mod;
    outputTexture.write(modPixel, gid);
}
