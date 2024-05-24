//
//  LumaBox.ci.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-05-23.
//

#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" float4 LumaBox (coreimage::sample_t s, float time, float intensity, coreimage::destination dest)
{
//    frame.y.par_chunks_mut(frame.dimensions.0).for_each(|y| {
//                    let mut delay = VecDeque::<f32>::with_capacity(4);
//                    delay.push_back(16.0 / 255.0);
//                    delay.push_back(16.0 / 255.0);
//                    delay.push_back(y[0]);
//                    delay.push_back(y[1]);
//                    let mut sum: f32 = delay.iter().sum();
//                    let width = y.len();
//
//                    for index in 0..width {
//                        // Box-blur the signal.
//                        let c = y[usize::min(index + 2, width - 1)];
//                        sum -= delay.pop_front().unwrap();
//                        delay.push_back(c);
//                        sum += c;
//                        y[index] = sum * 0.25;
//                    }
//                });
    return s;
}
