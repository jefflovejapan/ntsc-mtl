#  Scratchpad

## May 23

Looking at the Rust code, the main function is `NtscEffect.apply_effect_to_yiq_field`, which does the following:

1. Generates some initial data structures (width, random seed, "common info", scratch buffer)
2. Applies a luma filter to the yiq field
3. Applies a chroma lowpass filter if enabled
4. Does "chroma into luma" (???) if enabled
...

I think a good first goal is to apply the luma filter to the entire yiq field / frame

## May 25

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
- 
