//
//  VEAEAbstractChannel.h
//  VEAudioEngine Module for TheAmazingAudioEngine
//
//  Created by Leo Thiessen on 2015-01-21.
//  Copyright (c) 2015 Visions Encoded. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#ifndef VEAEAbstractChannel_h_INCLUDED
#define VEAEAbstractChannel_h_INCLUDED
#import "VEAEUtils.h"
EXTERN_C_BEGIN



@class VEAEAbstractChannel;


/// This is intended to be used internally to VEAEAbstractChannel subclasses and is used by _audHostTicksFromSeconds()
extern double _hTime2nsFactor;



/// This is intended to be used internally to VEAEAbstractChannel subclasses and can be useful for modulation calcs.
static inline UInt64 _audHostTicksFromSeconds(double seconds) {
    // See: http://stackoverflow.com/a/2806683
    return (1000000000.0 * seconds) * _hTime2nsFactor;
}



/// Designed primarly for internal &/or sub-class use. Can be used to modulate an AU parameter over a duration.
typedef struct _aud_modulate_param_t {
    BOOL active;
    UInt64 hostStartTime;
    float hostDuration;
    UInt64 hostEndTime;
    AudioUnitParameterValue startValue;
    AudioUnitParameterValue endValue;
    AudioUnitParameterValue valueDiff;
} _aud_modulate_param_t;



/// Designed primarly for internal &/or sub-class use. Can be used to stop active modulation of an AU parameter.
/// You should call this function from the main thread. This function blocks until the current render cycle on the
/// realtime audio thread completes so that you can then set the affected paramter and the modulation won't change it.
static inline void _audStopModulation(_aud_modulate_param_t *modulator, AEAudioController *audCtrlr) {
    if(modulator->active) {
        modulator->active = NO;
        // ensure the realtime thread is not mid-render before we return from this function
        [audCtrlr performSynchronousMessageExchangeWithBlock:nil];
    }
}



@interface VEAEAbstractChannel : NSObject <AEAudioPlayable> {
    // Declaring iVars here lets our sub-classes access these directly (without needing to re-declare them)
    AEAudioController *_audCtrlr; // this needs to be initialize by concrete sub-classes
    NSURL *_url;
    AudioStreamBasicDescription _asbd; // aka audioDescription
    AudioUnit _au; // aka audioUnit
    AUNode _auNode;
    BOOL _channelIsPlaying;
    BOOL _channelIsMuted;
    BOOL _outputIsSilence;
    BOOL _isLooping;
    float _dspGain;
    float _dspPan;
    _aud_modulate_param_t _modGain;
    _aud_modulate_param_t _modPan;
    ve_completion_block_t _modGainCompletionBlock;
    ve_completion_block_t _modPanCompletionBlock;
}


/// Original media URL (may be nil).
@property (nonatomic, readonly) NSURL *url;

/// The output audio format.
@property (nonatomic, readonly) AudioStreamBasicDescription audioDescription;

/// The audio unit used (may be NULL).
@property (nonatomic, readonly) AudioUnit audioUnit;

/// The audio graph node (may be NULL).
@property (nonatomic, readonly) AUNode audioGraphNode;

/// If this is NO, then the track will be silenced and no further render callbacks will be performed until set to YES.
@property (nonatomic, readwrite) BOOL channelIsPlaying;

/// If YES, this track will be silenced, but render callbacks will continue to be performed.
@property (nonatomic, readwrite) BOOL channelIsMuted;

/// Wether the last render cycle output silence or not.
/// Not KVO compliant.
@property (nonatomic, readonly) BOOL outputIsSilence;

/// Whether the audio track/sample loops.  This is set during init.
@property (nonatomic, readonly) BOOL isLooping;

/// The gain filter applied to the rendered audio.  Setting this value stops internal modulation on this property.
/// Range: >= 0.0 (be careful with going >1.0 because clipping is not checked for!).
/// Not KVO compliant.
@property (nonatomic, readwrite) float dspGain;

/// The pan filter applied to the rendered audio.  Setting this value stops internal modulation on this property.
/// Range: -1.0 (left) to 1.0 (right).
/// Not KVO compliant.
@property (nonatomic, readwrite) float dspPan;


/// Modulate the gain over time with an optional callback at completion.
/// Can be useful to fade out and stop or remove this channel rather than just suddenly stopping mid-playback.
- (void)dspGainTo:(float)gain duration:(float)seconds completion:(ve_completion_block_t)completion;

/// Modulate the pan over time with an optional callback at completion.
- (void)dspPanTo:(float)pan duration:(float)seconds completion:(ve_completion_block_t)completion;

/// Stops an active dsp gain modulation.
- (void)stopModulatingDspGain;

/// Stops an active dsp pan modulation.
- (void)stopModulationDspPan;

/// Returns true if dspGainTo: or dspPanTo: is currently executing on this object.
- (BOOL)isModulating;

/// Removes this channel from the audio controller.  If the audio is still playing (outputIsSilence==NO) and a positive
/// fadeOutDuration is provided, then a call to dspGainTo:duration:completion: will be made first, at the end of which
/// this channel will be removed from the audio controller.
- (void)removeSelf:(float)fadeOutDuration;


@end
EXTERN_C_END
#endif // VEAEAbstractChannel_h_INCLUDED