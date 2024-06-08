//
//  ShiftRowMidline.metal
//  ntsc-mtl-demo
//
//  Created by Jeffrey Blagdon on 2024-06-08.
//

#include <metal_stdlib>
using namespace metal;

kernel void shiftRowMidline
(
 texture2d<half, access::read> inputTexture [[texture(0)]],
 texture2d<half, access::read> randomTexture [[texture(1)]],
 texture2d<half, access::write> outputTexture [[texture(2)]],
 uint2 gid [[thread_position_in_grid]]
 ) {
    half4 yiqa = inputTexture.read(gid);
    /*
     // TODO: It seems like this only affects a single line, maybe not that urgent
     
     let mid_line = mid_line.unwrap();
     // Shift the entire row, but only copy back a portion of it.
     let mut tmp_row = vec![0.0; width];
     shift_row_to(
         row,
         &mut tmp_row,
         noisy_shift,
         BoundaryHandling::Constant(0.0),
     );

     let seeder = Seeder::new(info.seed)
         .mix(noise_seeds::HEAD_SWITCHING_MID_LINE_JITTER)
         .mix(info.frame_num);

     // Average two random numbers to bias the result towards the middle
     let jitter_rand = (seeder.clone().mix(0).finalize::<f32>()
         + seeder.clone().mix(1).finalize::<f32>())
         * 0.5;
     let jitter = (jitter_rand - 0.5) * mid_line.jitter;

     let copy_start = (width as f32 * (mid_line.position + jitter)) as usize;
     if copy_start > width {
         return;
     }
     row[copy_start..].copy_from_slice(&tmp_row[copy_start..]);

     // Add a transient where the head switch is supposed to start
     let transient_intensity = (seeder.clone().mix(0).finalize::<f32>() + 0.5) * 0.5;
     let transient_len = 16.0 * info.bandwidth_scale;

     for i in copy_start..(copy_start + transient_len.ceil() as usize).min(width) {
         let x = (i - copy_start) as f32;
         row[i] += (1.0 - (x / transient_len as f32)).powi(3) * transient_intensity;
     }

     */
    outputTexture.write(yiqa, gid);
}

