#  Settings and Defaults

```
pub struct NtscEffect {
    pub random_seed: i32,
    pub use_field: UseField,
    pub filter_type: FilterType,
    pub input_luma_filter: LumaLowpass,
    pub chroma_lowpass_in: ChromaLowpass,
    pub chroma_demodulation: ChromaDemodulationFilter,
    pub luma_smear: f32,
    pub composite_preemphasis: f32,
    pub video_scanline_phase_shift: PhaseShift,
    pub video_scanline_phase_shift_offset: i32,
    #[settings_block(nested)]
    pub head_switching: Option<HeadSwitchingSettings>,
    #[settings_block]
    pub tracking_noise: Option<TrackingNoiseSettings>,
    #[settings_block]
    pub composite_noise: Option<FbmNoiseSettings>,
    #[settings_block]
    pub ringing: Option<RingingSettings>,
    #[settings_block]
    pub luma_noise: Option<FbmNoiseSettings>,
    #[settings_block]
    pub chroma_noise: Option<FbmNoiseSettings>,
    pub snow_intensity: f32,
    pub snow_anisotropy: f32,
    pub chroma_phase_noise_intensity: f32,
    pub chroma_phase_error: f32,
    pub chroma_delay: (f32, i32),
    #[settings_block(nested)]
    pub vhs_settings: Option<VHSSettings>,
    pub chroma_vert_blend: bool,
    pub chroma_lowpass_out: ChromaLowpass,
    pub bandwidth_scale: f32,
}

impl Default for NtscEffect {
    fn default() -> Self {
        Self {
            random_seed: 0,
            use_field: UseField::Alternating,
            filter_type: FilterType::ConstantK,
            input_luma_filter: LumaLowpass::Notch,
            chroma_lowpass_in: ChromaLowpass::Full,
            chroma_demodulation: ChromaDemodulationFilter::Box,
            luma_smear: 0.0,
            chroma_lowpass_out: ChromaLowpass::Full,
            composite_preemphasis: 1.0,
            video_scanline_phase_shift: PhaseShift::Degrees180,
            video_scanline_phase_shift_offset: 0,
            head_switching: Some(HeadSwitchingSettings::default()),
            tracking_noise: Some(TrackingNoiseSettings::default()),
            ringing: Some(RingingSettings::default()),
            snow_intensity: 0.003,
            snow_anisotropy: 0.5,
            composite_noise: Some(FbmNoiseSettings {
                frequency: 0.5,
                intensity: 0.01,
                detail: 1,
            }),
            luma_noise: Some(FbmNoiseSettings {
                frequency: 0.5,
                intensity: 0.05,
                detail: 1,
            }),
            chroma_noise: Some(FbmNoiseSettings {
                frequency: 0.05,
                intensity: 0.1,
                detail: 1,
            }),
            chroma_phase_noise_intensity: 0.001,
            chroma_phase_error: 0.0,
            chroma_delay: (0.0, 0),
            vhs_settings: Some(VHSSettings::default()),
            chroma_vert_blend: true,
            bandwidth_scale: 1.0,
        }
    }
    
    impl Default for VHSSettings {
    fn default() -> Self {
        Self {
            tape_speed: Some(VHSTapeSpeed::LP),
            chroma_loss: 0.0,
            sharpen: Some(VHSSharpenSettings::default()),
            edge_wave: Some(VHSEdgeWaveSettings::default()),
        }
    }
}


```

