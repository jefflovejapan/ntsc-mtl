#  Scratchpad

# May 23

Looking at the Rust code, the main function is `NtscEffect.apply_effect_to_yiq_field`, which does the following:

1. Generates some initial data structures (width, random seed, "common info", scratch buffer)
2. Applies a luma filter to the yiq field
3. Applies a chroma lowpass filter if enabled
4. Does "chroma into luma" (???) if enabled
...

I think a good first goal is to apply the luma filter to the entire yiq field / frame

# May 25

### What's going on with filter_plane?

- Uses an IIR (infinite impulse response) filter 
- Called on YIQView
    - Is YIQView the whole field of pixels? Or does it only represent half of the rows because of interlacing?
        - It depends on UseField, it looks like. In most cases (?) this is going to be interlaced.
            - `apply_effect` calls `apply_effect_to_yiq`. We need a YiqField, but this is just an enum that's derived from UseField (identical thing)
            - The default for UseField is .alternating, which gives us either .upper or .lower depending on the timestamp
        - It's only half the 

### Questions for Valerie

- First processing step is `luma_filter` -- it seems like `.Box` just averages the luma across four neighboring pixels in the x dimension. Is that accurate? Any idea why we're only doing it in x, rather than doing a convolution of the 9 pixels in a square or something?
- There are a lot of "delay" parameters but it's not clear that these are actually introducing a temporal delay. Is that the intention? Does the YIQPlane represent multiple frames of data, like a ring buffer?
- It really seems like the alternating upper/lower stuff in YIQView in `apply_effect_to_yiq` was intended to interlace the rows but it looks like it's splitting the whole field into upper and lower parts. Does that sound right?
- What is `filter_signal_in_place` doing?
- Am I correct in assuming that initialCondition::firstSample takes the pixel (luma) value at the first position in the row and uses that for the entire row?

# May 26

OK, let's look at the outputImage code

```
override var outputImage: CIImage? {
    guard let inputImage else { return nil }
    let prevImage = previousImages.first ?? inputImage
    guard let num = numerators.first else { return nil }
    guard let filteredImage = Self.kernels.filterSample.apply(extent: inputImage.extent, arguments: [inputImage, prevImage, num]) else {
        return nil
    }
    for i in 0..<numerators.count {
        let nextIdx = i + 1
        guard nextIdx < previousImages.count, nextIdx < numerators.count else { break }
        if let img = Self.kernels.sideEffect.apply(extent: inputImage.extent, arguments: [inputImage, filteredImage, numerators[nextIdx], denominators[nextIdx]]) {
            previousImages[i] = img
        }
    }
    return Self.kernels.finalImage.apply(extent: inputImage.extent, arguments: [])
}
```

### Single coefficient

- Let's say 1 numerator/denominator
- On the 0th step, previousImages will be empty, so we'll pass the inputImage twice to filterSample
- The for loop is only going to contain index 0, so index 1 will be out of bounds
- There's no way to maintain state with a single numerator/denominator so the single coefficient case is constant

### Double coefficient

- Let's say 2 numerators/denominators
- On the 0th step, previousImages will be empty, so we'll pass the inputImage twice to filterSample

Input at t0

- First step of the for loop (input 0, index 0):
    - nextIdx (1) is valid
    - we haven't built up previousImages yet so we need to use inputImage0 again I guess?
    - previousImages[0] = f(inputImage0, inputImage0, num[1], den[1])
- Second step of the for loop (input 0, index 1)
    - nextIdx (2) is invalid
    
Input at t1 
    
- First step of the for loop (input 1, index 0):
    - nextIdx (1) is valid
    - we have a previous image now
    - previousImages[0] = f(input 1, previous 0, num[1], den[1])

## Debugging `luma_notch`

- The Rust code uses initialSample, right?
    - Yes, ntsc.rs line 208
- Does initialSample do what I think it does?
    - in `filter_plane_with_rows` we switch on `initial` to get a single float
    - in the case of `firstSample` it's `row[0]` -- does that mean that the same pixel value is used for all pixels in the row?
        - question for Valerie: 
    
- Does the math check out for `luma_notch`?
- Can I write a test that verifies it works the way I expect?
- I think my IIR implementation is wrong. Let's revisit

### `filter_signal_in_place_impl`

```
/// The row of samples
for samp_idx in 0..N {
    // An individual pixel
    let signal = &mut signal[samp_idx];
    // Iterate over the entire sample plus the delay -- why?
    for i in 0..(signal.len() + delay) {
        // guarding that we don't sample out of bounds
        let sample = unsafe { signal.get_unchecked(i.min(signal.len() - 1)) };
        let filt_sample =
            Self::filter_sample(filter_len, num, den, z[samp_idx], *sample, scale);
        if i >= delay {
            signal[i - delay] = filt_sample;
        }
    }
```

If we weren't doing any filtering, we'd be replacing data in the current frame


### Current IIR Filter implementations

- Composite preemphasis
- Chroma lowpass (full and lite)
- Luma notch blur


### Stuff to look into

- MetalKit view (to be sure) ✅
- testing against Rust values
- better understanding of what the lowpass filters are/should be doing
- What happens if we use SDR video as the input?

- It doesn't matter how many times we feed the same color through the filter, the effect is the same
- We shouldn't see that initial bump in luma though -- what is happening?

- the transfer function is:
    - the arguments for frequency and quality are 0.5 and 2 (same in Rust code)
    - initial condition is firstSample (same in Rust code)
    -   

        let numerators: [Float] = [gain, middleParam, gain]
        let denominators: [Float] = [1, middleParam, (2 * gain) - 1]
- To check floating point error stuff you can just 

Breakthrough!!

- The initial state of the buffers in Rust is *not* equal to the input color. There's something else happening here.
- There's a z[i] for every sample. That means that z needs to be the size of the image. It also means that we should be able to initialize it to some value f(initialCondition, firstSample)
- The size of z is equal to the number of nums/dens (so 4 in this case)
- The `value` argument to `initial_condition` is (I think) the sample/pixel value. 
- `first_nonzero_coeff` is 1 (verified since we know that 1 is the first denominator for our transfer function)
- is `initial_condition` only called sometimes? Why do we have .none, .initialSample, and .constant?
- z[i] just needs to store a value. There are as many zs are there are numerators and denominators. I don't think I need a texture, I just need n zs.
- To set up the initial condition I just fill z up using a function of initialCondition, initialSample, and numerators and denominators
    - It might be possible to parallelize this into a single texture, but that's mega-optimizing. For now we can perform the iteration in initialCondition using CIImages and the initial image
    
## More Rust debugging

- The values I'm getting out of luma blur in Rust still don't match what I'm seeing in Swift -- why?
    - What are the values of z after running the setup for a 0.5 in Rust?
    - What about in Swift?
- The chroma lowpass looks crazy
    - If the initial value is 0/black am I short-circuiting appropriately?
    - What are the values of z after running the setup for a 0.5 in Rust?
    - What about in Swift?
    
    
### Rust
- Before entering the loop
    - zi[0] is 0.292893231
- At the bottom of i = 1
    - `a_sum` is just over 1 (1.00000012)
    - `b_sum` is 0.414213598
    - `c_sum` is 1.8105851E-8
    - `zi[0]` is 0.292893231
    - `norm_num` is [0.707106769, 6.18172393E-8, 0.707106769, ...] (I think the last one is a 0)
    - `norm_den` is [1, 6.18172393E-8, 0.414213538, 0]
    - z is [0.292893231, 0.146446615, 0, 0]
- At the end of it all:
    - `a_sum` is 1.41421366
    - `b_sum` is 0.414213598
    - `c_sum` is 0.414213598
    - `zi` is [0.292893231, 0.146446615, 0, 0]


### Swift
- Before entering the loop
    - z0Fill is 0.29289323 ✅
- At the bottom of i = 1
    - `aSum` is 0.9999999 🟡
    - `bSum` is 0.41421354 ✅
    - `cSum` is -3.1272258e-08 🟡
    - `z0` is 0.29289323 ✅
    - normalizedNumerators is [0.70710677, -1.0677015e-07, 0.70710677] ✅
    - normalizedDenominators is [1.0, -1.0677015e-07, 0.41421354] 🟡 (the subtle sign error in that second term is bothering me)
    - z1 is inputImage (0.5), sideEffected(0.292893), aSum = 1, cSum is nearly 0. Calling IIRInitialCondition gives us **0.1464465**, which is what the Rust code gives us ✅
- At the bottom of i = 2
    - z2 is inputImage (0.5), sideEffected(0.292893), aSum = 1.41421, cSum is 0.414214. Calling IIRInitialCondition gives us **0.1464465**, which is what the Rust code gives us ✅
- At the end of it all:
    - aSum is 1.4142134 ✅
    - bSum is 0.41421354 ✅
    - cSum is 0.41421354 ✅

### Is the bug in the initialCondition kernel?

- 
- Swift
    - We call it with image (the input image), initialZ0Image (the z0-filled image), aSum, and cSum
- Rust
    - We call `zi[i] = (a_sum * zi[0] - c_sum) * value;`
    - `value` is 0.5 (our input value / red channel)

## Chroma Lowpass debugging

### Rust

- numerators and denominators to the i function:
    - numerators are [b0 = 0.0572976321, b1 = 0.114595264, b2 = 0.0572976321]
    - denominators are (1, a1 = -1.218135, a2 = 0.447325468)
- numerators and denominators to the q function:
    - numerators are b0 = 0.0145529797, b1 = 0.0291059595, b2 = 0.0145529797

### Swift

- numerators and denominators to the i function:
    - 
- Hypothesis: different numerical formats but we're far enough away from the bounds

# Jun 3

- I think I'm so close to getting this to work. I have reliable tests that can convert to/from RGB/YIQ. Everything looks more or less right for reach phase of the filter. I just need to run it one more time, comparing with Rust, then looking at the composite result. I also need to investigate what we get for the RGB output on both sides to make sure the return conversion works correctly.
- I've pinpointed an issue and it's bad for the project. The issue is that moving from YIQ back to RGB is lossy -- we're dropping negative values somewhere along the way. This can be verified in the test `test_i_lowpass_butterworth` in the Rust code -- we're getting back some values that don't correspond to a simple to_rgb conversion on the plane data. It's hard to pinpoint exactly where this is getting adjusted, but my suspicion is that it's somewhere in the `RgbImage::from` path.
    - This is pretty much a dead end for the current strategy, because the expectation was that we'd always be able to move losslessly back and forth between RGB and YIQ. The only real way to solve this at this point is to rely on textures that can hold YIQ data. This means another big rewrite. Do I really want to do this?

# Jun 4

NTSCTextureFilter implementation. What I need:

- A single filter that represents the stateful, cumulative effect of applying a number of sub-filters
- Setting inputImage should wipe the current texture, rebuilding it if necessary, and replacing its contents with the input image
- Call a number of shader functions that all replace the content of the texture in-place
    - Need to double-check that our ToYIQ and ToRGB functions work
    - We'll need to hold onto an instance of an IIRTextureFilter with multiple textures each for all of the IIR steps
- Do I instantiate / set up NTSCTextureFilter with a single pixel? Or do I call the kernel functions directly?
    - I think calling the kernel functions directly is better than trying to make the filter testable from the outside. Too much juggling -- use unit tests instead.
- Wow, finally got a handle on Metal a little bit. Cool learnings:
    - The commandBuffer is just what it sounds like -- a buffer of commands. You encode one or more commands to it, then commit it, and optionally wait for it to complete
    - This means that we can chain arbitrary Metal commands together and run them all at once, every frame. Just for right now, I'm:
        - writing a CIImage to a texture
        - converting those rgb values to YIQ values in place
        - blurring them using a scratch texture and blit encoder (finally figured out what blitting is!)
            - blit the work-in-progress texture to the scratch texture
            - blur the scratch texture
            - compose the luma value from the scratch texture with the chroma ones from the work-in-progess texture
            - write the composition back to the WIP
- Excited to try the IIR filter next
- Making good progress on IIR but luma notch doesn't seem to be working. If it's not texture misuse what could it be? It's almost like nothing's happening at all.
    - There's a real answer to this. It was on the tip of my tongue and then I forgot
    - Oh right, not allocating threads etc.

## Debugging Overflow

- Can the numerators and denominators for our transfer function be constrained within Float16 range?
    - Test all possible code paths
    
- IIRTransferFunction
    - notchFilter
        - called with frequency 0.5, quality 2
    - lowpassFilter
        - called by ChromaLowpassTextureFilter.lowpassFilter
            - called by ChromaLowpassTextureFilter.init with cutoffs of 1_300_000, 600_000 and 2_600_000 and rates equal to NTSC.rate * bandwidthScale where bandwidthScale is 1.0
    - butterworth
        - called by ChromaLowpassTextureFilter.lowpassFilter
        - called by ChromaLowpassTextureFilter.init with the same cutoffs and rates as above

OK, realized in first test that numerators and denominators can overflow float16. That means we'll have to pass Floats to the textures and hopefully the shader operations result in values that are within float16 range

- The issue is probably not an overflow, but is probably related to single-buffering the IIR filter. Need to review the pipeline for places where we're reading from / writing to the same buffer
    - **IIRInitialCondition we're single buffering** ✅
    - **IIRMultiply we're single buffering** ✅
    - **IIRFinalImage we're single buffering** ✅
  
## Office Hours
            
- Whimsical, goofy stuff is cool
- Synth is some kidn of analog filter -- is there some way that you can run the same signal through a video?
- Audio hang is on Tuesdays
- Portfolio approach is also cool -- do a bunch of smaller things and blog about them
    - Pair with folks on doing an audio-to-video filter 
- Blogging makes however you've been spending your time interesting and worthwhile
- Pairing with people can be cool
    - Ask for help with your thing!

## Jun 7

- Realizeed late last night that the issue I'm running into is probably from single-buffering in multiple places
- Rewriting the filter to double buffer
- Trying to decide how hard I should try to optimize here
    - How many textures do I actually need?
    - When are the z-textures no longer used?
        - By the time we get to filterSample we're only using z0. Otherwise zs are done.
    - What happens with the "initial condition texture" -- is it used in filterSample?
        - No, only input and z0
        - Can ignore the "zero" case for initial condition
- Initial condition
- Do I need to be worried that the values I'm pulling are underflowing to 0 when Rust still has precision? Should I be using Float32 textures for z (and maybe others?)
- It looks like the issue may have had to do with filling z0 after all. Wrote a paint function to do what I want.
- Finally got it working. What a relief

### Performance

- Down to about 30fps with standard (everything) config
- Input luma
    - no problem with box
    - notch isn't nearly as bad as chroma lowpass
- What if we ditch the phase stuff? (chroma into luma)
    - Doesn't really make a difference
- How about chroma lowpass?
    - kills us ☝️☝️☝️
- Chroma into luma?
    - no difference
- Composite preemphasis
    - no diff
- Composite noise
    - no diff
- Snow
    - completely boned

### Debugging ConstantK

- First pass of cascade
    - Swift
        - nums: [0.3632493, 0.0] (for both left and right)
            - trimmedZeroes: [0.3632493] (seems wrong)
                - not wrong, same thing in Rust
        - dens: [1.0, -0.6367507] (for both left and right)
            - trimmedZeroes: no change (for either left or right)
            - trimmedZeroes: same for Rust
        - polynomialMultiply
            - a and b are both equal to 0.3632493 (for nums)
            - a and b are both equal to [1.0, -0.6367507] (for dens)
        - second pass (already returned out for nums and dens once)
            - a nums are [0.131950051] and b are [0.363249302]
                - same in Rust
            - out is [0.0479] in Rust
            - out is 
    - Rust
        - polynomialMultiply
            - a and b are both the 0.36 number
            - degree 1
                - first loop ai and bi are both 0
                    - out = [0.131950051]
                - only one loop
                - returning [0.131950051]
            - a and b are identical to Swift for dens
                - out is [1.0, -1.27, 0.405] for both swift and rust

- This is too confusing. Here's all the invocations from Rust:

poly_mul_count: 0
a in: [0.3632493]
b in: [0.3632493]
degree: 1
ai: 0
a[ai]: 0.3632493
bi: 0
b[bi]: 0.3632493
out: [0.13195005]
poly_mul_count: 1
a in: [1.0, -0.6367507]
b in: [1.0, -0.6367507]
degree: 3
ai: 0
a[ai]: 1.0
bi: 0
b[bi]: 1.0
ai: 0
a[ai]: 1.0
bi: 1
b[bi]: -0.6367507
ai: 1
a[ai]: -0.6367507
bi: 0
b[bi]: 1.0
ai: 1
a[ai]: -0.6367507
bi: 1
b[bi]: -0.6367507
out: [1.0, -1.2735014, 0.40545145]
poly_mul_count: 2   // And here in Rust we're being called with different args
a in: [0.13195005]
b in: [0.3632493]
degree: 1
ai: 0
a[ai]: 0.13195005
bi: 0
b[bi]: 0.3632493
out: [0.047930762]
poly_mul_count: 3
a in: [1.0, -1.2735014, 0.40545145]
b in: [1.0, -0.6367507]
degree: 4
ai: 0
a[ai]: 1.0
bi: 0
b[bi]: 1.0
ai: 0
a[ai]: 1.0
bi: 1
b[bi]: -0.6367507
ai: 1
a[ai]: -1.2735014
bi: 0
b[bi]: 1.0
ai: 1
a[ai]: -1.2735014
bi: 1
b[bi]: -0.6367507
ai: 2
a[ai]: 0.40545145
bi: 0
b[bi]: 1.0
ai: 2
a[ai]: 0.40545145
bi: 1
b[bi]: -0.6367507
out: [1.0, -1.9102521, 1.2163544, -0.2581715]

- And here they are in swift

poly_mul_count: 0
a in: [0.3632493]
b in: [0.3632493]
degree: 1
ai: 0
a[ai]: 0.3632493
bi: 0
b[bi]: 0.3632493
out: [0.13195005]   // Here's the bug -- we're returning the same value as the Rust here
poly_mul_count: 1   // Then we do denoms
a in: [1.0, -0.6367507]
b in: [1.0, -0.6367507]
degree: 3
ai: 0
a[ai]: 1.0
bi: 0
b[bi]: 1.0
ai: 0
a[ai]: 1.0
bi: 1
b[bi]: -0.6367507
ai: 1
a[ai]: -0.6367507
bi: 0
b[bi]: 1.0
ai: 1
a[ai]: -0.6367507
bi: 1
b[bi]: -0.6367507
out: [1.0, -1.2735014, 0.40545145]
poly_mul_count: 2   // Then we do nums again but we're being called with the same args twice
a in: [0.13195005]
b in: [0.13195005]
degree: 1
ai: 0
a[ai]: 0.13195005
bi: 0
b[bi]: 0.13195005
out: [0.017410817]
poly_mul_count: 3
a in: [1.0, -1.2735014, 0.40545145]
b in: [1.0, -1.2735014, 0.40545145]
degree: 5
ai: 0
a[ai]: 1.0
bi: 0
b[bi]: 1.0
ai: 0
a[ai]: 1.0
bi: 1
b[bi]: -1.2735014
ai: 0
a[ai]: 1.0
bi: 2
b[bi]: 0.40545145
ai: 1
a[ai]: -1.2735014
bi: 0
b[bi]: 1.0
ai: 1
a[ai]: -1.2735014
bi: 1
b[bi]: -1.2735014
ai: 1
a[ai]: -1.2735014
bi: 2
b[bi]: 0.40545145
ai: 2
a[ai]: 0.40545145
bi: 0
b[bi]: 1.0
ai: 2
a[ai]: 0.40545145
bi: 1
b[bi]: -1.2735014
ai: 2
a[ai]: 0.40545145
bi: 2
b[bi]: 0.40545145


### Head Switching

- calculate a rowshift and noisyshift
    - rowShift: can pass shift and offset into kernel along with width (although you can call get_width inside the kernel)
    - noisyShift: `(rowShift + random - 0.5) * bandwidthScale`
    - if we've got midLine stuff then we do a bunch of extra math, otherwise we shiftRow(row, noisyShift, boundaryHandling of 0)
        - we shift the row by a non-integer amount using linear interpolation
- I think my implementation's still a little off

# June 9th

OK, spent the whole weekend here but made big progress

I think I finally have the IIR delay stuff figured out and hopefully there's a simple implementation that just involves translating the inputImage for IIR filters. Actually a better way to do it might be in the final compose step -- keep everything in shader land.

I kind of don't want to put this project down but I feel like I'll regret it if I just work on this for the whole retreat. Then again, I might be able to go really far with this. If I focused on it for the next three weeks I could probably have a real library launched and maybe even an app in the App Store.

I think I can demonstrate the value of this to the rest of the team, and maybe continue to work on it when I'm back at 1SE. The only thing that's better than getting paid to work on a passion project is getting paid to work on my *own code*. This is such a cool thing and genuinely interesting for talks and stuff.

The web stuff is cool and I might not have another chance to work on it soon. Then again, with ChatGPT I can always grab enough web code to get by (right?)

# June 10th

Hopefully starting on web stuff today! Feels like I made great progress over the weekend even though at the time it might have felt slow.

# June 12th

Yesterday was impossibilities day -- had a great time hacking with Paul and was really impressed with his knowledge of audio stuff. Everyone here is so talented -- it seems like even very young pepole have a mastery over the subject that I don't know if I'll ever have. That said, it has been cool seeing people's reactions to the projects I'm working on -- it feels like people think they're legitimately cool and aren't just being nice.

Today is all about getting snow to work. I think I've convinced myself that the approach can be a lot simpler, getting rid of all the looping that we have in Valerie's code. I can get geometric noise onscreen, but something is getting lost in the conversion from noise to snow. Should hopefully have something by the end of the day, then I can move on to things like the remaining noise stuff.

# Jun 13

- Had a great chat with Carsten about the project he's working on. It's way gnarlier than I thought -- he's using a kind of unsupported C++ thing and has had to teach himself enough C++ to dig around and try to make sense of it
- Hoping to demo today but need to make the filter interactive. Not a lot of time to get that done so hoping to lock in for the next few hours
- 

# Jun 14

- Had fun yesterday making the filter interactive. It was easier than I thought by making NTSCEffect an @Observable class and sharing it between different components. Showed it to Paul and Seamus and they were pretty stoked on it. Had fun playing with the Oscilloscope. Talked to Jeremy about ctf, which is so far out of my realm I have no idea.
- Today I want to knock out interlacing, make sure bandwidth scale works correctly, and *hopefully* knock out snow

## Bandwidth scale audit

- `composite_chroma_lowpass`: ✅
- `luma_smear`: ✅
- `composite_noise`: ✅
- `head_switching`: ✅ (still need midline)
- `plane_noise`
    - `luma_noise`: Still just blit
    - `chroma_noise`: Still just blit
- `snow` -- still WIP
- `tracking_noise` -- haven't started
- `chroma_delay` -- ✅
- ...

## Prioritizing remaining work

- Tracking noise would be the coolest but requires `row_speckles`
- Would be great to get snow down so we have it. We're super close
- Remaining "just blits":
    - ringing
        - seems relatively important
        - deals with ffts
    - chroma into luma
        - we're supposed to do it independently of the vhs one
        - looks like the same function so we can reuse?
    - composite preemphasis
        - depends on composite preemphasis cut
        - default is > 0 though so should probably add
    - video noise
        - would be nice to have some noise
        - it looks like it's uniform random noise
        - OK, slightly more structured, but not Perlin noise
    - chroma from luma
        - only need this if "no color subcarrier" is true (false by default)
    - video chroma noise
        - noise is nice
    - video chroma phase noise
        - noise is nice
    - vhs chroma loss
        - 0 by default
    - composite lowpass
        - want if `composite_in_chroma_lowpass` is true (true by default)
    - color bleed out
        - we either color bleed before or after, just need a toggle to locate it in the pipeline
    - blur chroma
        - nice to have

### Performance

- Could have the filter function differently:
    - Expose a texture to render to (e.g., inTextures.first, or a single named texture)
    - Run the filter
    - Filter returns pool.last
    - Consumer can then blit to drawable.texture, present drawable, commit buffer
- Feels like waiting for the output image on every iteration of the filter is killing us
- Also need to check whether making the texture bgra again makes a difference

