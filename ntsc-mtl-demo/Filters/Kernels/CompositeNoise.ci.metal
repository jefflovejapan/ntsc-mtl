//
//  CompositeNoise.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-27.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

static float perlinNoise(float2 uv) {
    // Implement Perlin or Simplex noise function here
    // This is a simplified placeholder for illustration purposes
    return fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

/*
 video_noise_line(
     // row
     row,
     // seeder
     &seeder,
     // index
     index,
    // frequency
     noise_settings.frequency / info.bandwidth_scale,
     noise_settings.intensity,
     noise_settings.detail,
 );
 
 fn video_noise_line(
     row: &mut [f32],
     seeder: &Seeder,
     index: usize,
     frequency: f32,
     intensity: f32,
     detail: u32,
 ) {
     let width = row.len();
     let mut rng = Xoshiro256PlusPlus::seed_from_u64(seeder.clone().mix(index as u64).finalize());
     let noise_seed = rng.next_u32();
     let offset = rng.gen::<f32>() * width as f32;

     let noise = NoiseBuilder::fbm_1d_offset(offset, width)
         .with_seed(noise_seed as i32)
         .with_freq(frequency)
         .with_octaves(detail.clamp(1, 5) as u8)
         // Yes, they got the lacunarity backwards by making it apply to frequency instead of scale.
         // 2.0 *halves* the scale each time because it doubles the frequency.
         .with_lacunarity(2.0)
         .generate()
         .0;

     row.iter_mut().enumerate().for_each(|(x, pixel)| {
         *pixel += noise[x] * 0.25 * intensity;
     });
 }
 */

extern "C" float4 FractalNoise(coreimage::sample_t sample, float frequency, float amplitude, int octaves, float lacunarity, float offset, coreimage::destination dest) {
    float2 uv = dest.coord();
    uv.x = fract(uv.x + offset);
    float noise = 0.0;
    float maxAmplitude = 0.0;
    float currentFrequency = frequency;
    float currentAmplitude = amplitude;

    for (int i = 0; i < octaves; i++) {
        noise += currentAmplitude * perlinNoise(uv * currentFrequency);
        maxAmplitude += currentAmplitude;
        currentFrequency *= lacunarity;
    }

    noise /= maxAmplitude;

    return float4(noise, noise, noise, 1.0);
}
