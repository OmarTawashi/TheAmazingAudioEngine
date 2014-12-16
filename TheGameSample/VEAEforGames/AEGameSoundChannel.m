//
//  AEGameSoundChannel.m
//  TheAmazingAudioEngine
//
//  This file is based on "AEAudioUnitChannel.m" which was created by Michael
//  Tyson on 01/02/2013.
//
//  This file was created by Leo Thiessen on 10/12/2014.
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

#import "AEGameSoundChannel.h"

#define checkResult(result,operation) (_checkResult((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _checkResult(OSStatus result, const char *operation, const char* file, int line) {
    if ( result != noErr ) {
        int fourCC = CFSwapInt32HostToBig(result);
        NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&fourCC);
        return NO;
    }
    return YES;
}

// These functions turn various float ranges (matching typical OpenAL ranges)
// to MIDI 0-127 ranges and as the AUSampler needs them, at least for the
// parameters we're adjusting dynamically.  All input values are clamped so
// we get return values in the expected ranges.
static inline float _floatVolumeToMidiVolume(float floatVolume) { return 127 * MAX(0.0, MIN(1.0, floatVolume)); }               // returns 0 to 127
//static inline float _midiVolumeToFloatVolume(float zeroTo127) { return MAX(0,MIN(127,(float)zeroTo127)) / 127.0; }              // returns 0 to 1.0
static inline float _floatPanToMidiPan(float floatPan) { return 127 * MAX(0.0, MIN(1.0, ((floatPan + 1.0) * 0.5))); }           // returns 0 to 127
//static inline float _midiPanToFloatPan(float zeroTo127) { return ((MAX(0,MIN(127,(float)zeroTo127)) / 127.0) * 2.0) - 1.0; }    // returns -1.0 to 1.0
static inline float _floatPitchToMidiPitch(float floatPitch) { return 127 * MAX(0.0, MIN(1.0, floatPitch * 0.5)); }             // returns 0 to 127
//static inline float _midiPitchToFloatPitch(float zeroTo127) { return (MAX(0,MIN(127,(float)zeroTo127)) / 127.0) * 2.0; }        // returns 0 to 2.0

static inline UInt64 _secondsToHostTicks(float seconds) {
    static BOOL needToGetTInfo = YES;
    static double hTime2nsFactor = 1.0; // safe default for our purposes - would result in extremely short # of ticks if not changed to tinfo based value
    kern_return_t kerror;
    mach_timebase_info_data_t tinfo;
    if(needToGetTInfo) {
        kerror = mach_timebase_info(&tinfo);
        if(kerror == KERN_SUCCESS) {
            hTime2nsFactor = (double)tinfo.numer / tinfo.denom;
            needToGetTInfo = NO;
        }
    }
    // See: http://stackoverflow.com/a/2806683
    return (1000000000 * seconds) / hTime2nsFactor;
}

typedef struct _modulate_param_5 {
    BOOL active;
    UInt64 hostStartTime;
    float hostDuration;
    UInt64 hostEndTime;
    AudioUnitParameterValue startValue;
    AudioUnitParameterValue endValue;
    AudioUnitParameterValue valueDiff;
} modulate_param_t;


@implementation AEGameSoundChannel {
    NSURL *_fileURL;
    
    float _auPan, _auPitchBend, _auVolume;
    
    modulate_param_t _modulateVolume;
    modulate_param_t _modulatePitchBend;
    modulate_param_t _modulatePan;
    
    BOOL _needToAddSelfAsTimingReceiver;
}

@synthesize url=_fileURL;
@synthesize loop=_loop;

- (id)initWithFileURL:(NSURL*)fileURL
      audioController:(AEAudioController*)audioController
           shouldLoop:(BOOL)shouldLoop
                cents:(int)cents
                error:(NSError**)error {
    return [self initWithFileURL:fileURL audioController:audioController preInitializeBlock:NULL shouldLoop:shouldLoop cents:cents error:error];
}

- (id)initWithFileURL:(NSURL*)fileURL
      audioController:(AEAudioController*)audioController
   preInitializeBlock:(void(^)(AudioUnit audioUnit))block
           shouldLoop:(BOOL)shouldLoop
                cents:(int)cents
                error:(NSError**)error {
    
    // Set iVars
    _needToAddSelfAsTimingReceiver = YES; // done "lazily"
    _auPan = 0.0; // center
    _auPitchBend = 1.0; // at-pitch
    _auVolume = 1.0; // full volume
    _modulateVolume.active = NO; // just for clarity
    _modulatePitchBend.active = NO;
    _modulatePan.active = NO;
    _fileURL = fileURL;
    _loop = shouldLoop;
    
    // Load the .aupreset file
    NSMutableDictionary *aupreset = [NSMutableDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"AEGameSoundChannel" withExtension:@"aupreset"]];
    if(aupreset == nil) {
        if(error) {
            *error = [NSError errorWithDomain:@"nil for required object" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Couldn't initialise audio unit: missing the aupreset"}];
        }
        return nil;
    }
    
    // Modify the aupreset dictionary
    [[aupreset objectForKey:@"file-references"] setValue:[_fileURL path] forKey:@"Sample:268435457"];
    NSDictionary *zone = [[[aupreset objectForKey:@"Instrument"] objectForKey:@"Layers"][0] objectForKey:@"Zones"][0];
    [zone setValue:@(_loop) forKey:@"loop enabled"];
    float f    = ((float)cents) / 100.0;
    int coarse = (int)f;
    int fine   = (int)((f - ((float)coarse)) * 100.0);
    [zone setValue:[NSNumber numberWithInt:coarse] forKey:@"coarse tune"]; // full semi-tones
    [zone setValue:[NSNumber numberWithInt:fine] forKey:@"fine tune"];     // cents in-between semi-tones
    
    // Init the AEAUSamplerChannel
    return [super initWithDictionary:aupreset audioController:audioController preInitializeBlock:block error:error];
}

#pragma mark - Declared Properties

- (float)auVolume {
    return _auVolume;
}

- (void)setAuVolume:(float)auVolume {
    if(_modulateVolume.active) {
        _modulateVolume.active = NO; // stop modulation on the audio render thread
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setAuVolume:auVolume];
        });
        return; // will wait a fraction of a second for modulation to stop
    } else {
        // The value we set is actually a MIDI value between 0 to 127
        if(checkResult(AudioUnitSetParameter(_audioUnit, kAUGroupParameterID_Volume, kAudioUnitScope_Group, 0, _floatVolumeToMidiVolume(auVolume), 0), "AudioUnitSetParameter(kAUGroupParameterID_Volume) failed")) {
            _auVolume = MAX(0,MIN(1.0, auVolume));
        }
    }
}

- (float)auPan {
    return _auPan;
}

- (void)setAuPan:(float)auPan {
    if(_modulatePan.active) {
        _modulatePan.active = NO; // stop modulation on the audio render thread
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setAuPan:auPan];
        });
        return; // will wait a fraction of a second for modulation to stop
    } else {
        // The value we set is actually a MIDI value between 0 to 127
        if(checkResult(AudioUnitSetParameter(_audioUnit, kAUGroupParameterID_Pan, kAudioUnitScope_Group, 0, _floatPanToMidiPan(auPan), 0), "AudioUnitSetParameter(kAUGroupParameterID_Pan) failed")) {
            _auPan = MAX(-1.0, MIN(1.0, auPan));
        }
    }
}

- (float)auPitchBend {
    return _auPitchBend;
}

- (void)setAuPitchBend:(float)auPitchBend {
    if(_modulatePitchBend.active) {
        _modulatePitchBend.active = NO; // stop modulation on the audio render thread
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setAuPitchBend:auPitchBend];
        });
        return; // will wait a fraction of a second for modulation to stop
    } else {
        // The value we set is actually a MIDI value between 0 to 127
        if(checkResult(AudioUnitSetParameter(_audioUnit, kAUGroupParameterID_PitchBend, kAudioUnitScope_Group, 0, _floatPitchToMidiPitch(auPitchBend), 0), "AudioUnitSetParameter(kAUGroupParameterID_PitchBend) failed")) {
            _auPitchBend = MAX(0.0, MIN(2.0, auPitchBend));
        }
    }
}

#pragma mark - Declared Methods

- (void)auPanTo:(float)auPanTo duration:(float)duration {
    if(_needToAddSelfAsTimingReceiver) {
        _needToAddSelfAsTimingReceiver = NO;
        [_audioController addTimingReceiver:self];
    }
    if(_modulatePan.active) {
        // Clear it first
        _modulatePan.active = NO;
        UInt64 timeBefore = mach_absolute_time();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // call ourselves back with the delay compensated for
                [self auPanTo:auPanTo duration:MAX(0.05, duration - (float)((mach_absolute_time() - timeBefore)/NSEC_PER_SEC))];
            });
        });
        return; // will wait a fraction of a second for previous modulation to stop
    }
    _modulatePan.startValue = _floatPanToMidiPan(_auPan); // current pan
    _modulatePan.endValue = _floatPanToMidiPan(auPanTo);
    if(((int)_modulatePan.startValue) != ((int)_modulatePan.endValue)) { // check if we even need to modulate
        _modulatePan.valueDiff = _modulatePan.endValue - _modulatePan.startValue;
        _modulatePan.hostStartTime = mach_absolute_time();
        _modulatePan.hostDuration = _secondsToHostTicks(MAX(0.05,duration));
        _modulatePan.hostEndTime = _modulatePan.hostStartTime + _modulatePan.hostDuration; // set future time to be finished by - this "host time" supposedy stops when the machine stops or sleeps, which in our case is good, as our modulation should wait then too
        _modulatePan.active = YES; // activate it!
    }
}

- (void)auPitchBendTo:(float)auPitchBendTo duration:(float)duration {
    if(_needToAddSelfAsTimingReceiver) {
        _needToAddSelfAsTimingReceiver = NO;
        [_audioController addTimingReceiver:self];
    }
    if(_modulatePitchBend.active) {
        // Clear it first
        _modulatePitchBend.active = NO;
        UInt64 timeBefore = mach_absolute_time();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // call ourselves back with the delay compensated for
                [self auPitchBendTo:auPitchBendTo duration:MAX(0.05, duration - (float)((mach_absolute_time() - timeBefore)/NSEC_PER_SEC))];
            });
        });
        return; // will wait a fraction of a second for previous modulation to stop
    }
    _modulatePitchBend.startValue = _floatPitchToMidiPitch(_auPitchBend); // current
    _modulatePitchBend.endValue = _floatPitchToMidiPitch(auPitchBendTo);
    if(((int)_modulatePitchBend.startValue) != ((int)_modulatePitchBend.endValue)) { // check if we even need to modulate
        _modulatePitchBend.valueDiff = _modulatePitchBend.endValue - _modulatePitchBend.startValue;
        _modulatePitchBend.hostStartTime = mach_absolute_time();
        _modulatePitchBend.hostDuration = _secondsToHostTicks(MAX(0.05,duration));
        _modulatePitchBend.hostEndTime = _modulatePitchBend.hostStartTime + _modulatePitchBend.hostDuration; // set future time to be finished by - this "host time" supposedy stops when the machine stops or sleeps, which in our case is good, as our modulation should wait then too
        _modulatePitchBend.active = YES; // activate it!
    }
}

- (void)auVolumeTo:(float)auVolumeTo duration:(float)duration {
    if(_needToAddSelfAsTimingReceiver) {
        _needToAddSelfAsTimingReceiver = NO;
        [_audioController addTimingReceiver:self];
    }
    if(_modulateVolume.active) {
        // Clear it first
        _modulateVolume.active = NO;
        UInt64 timeBefore = mach_absolute_time();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // call ourselves back with the delay compensated for
                [self auVolumeTo:auVolumeTo duration:MAX(0.05, duration - (float)((mach_absolute_time() - timeBefore)/NSEC_PER_SEC))];
            });
        });
        return; // will wait a fraction of a second for previous modulation to stop
    }
    _modulateVolume.startValue = _floatVolumeToMidiVolume(_auVolume); // current
    _modulateVolume.endValue = _floatVolumeToMidiVolume(auVolumeTo);
    if(((int)_modulateVolume.startValue) != ((int)_modulateVolume.endValue)) { // check if we even need to modulate
        _modulateVolume.valueDiff = _modulateVolume.endValue - _modulateVolume.startValue;
        _modulateVolume.hostStartTime = mach_absolute_time();
        _modulateVolume.hostDuration = _secondsToHostTicks(MAX(0.05,duration));
        _modulateVolume.hostEndTime = _modulateVolume.hostStartTime + _modulateVolume.hostDuration; // set future time to be finished by - this "host time" supposedy stops when the machine stops or sleeps, which in our case is good, as our modulation should wait then too
        _modulateVolume.active = YES; // activate it!
    }
}

#pragma mark - Overloaded

static OSStatus renderCallback(__unsafe_unretained AEGameSoundChannel *THIS,
                               __unsafe_unretained AEAudioController *audioController,
                               const AudioTimeStamp     *time,
                               UInt32                    frames,
                               AudioBufferList          *audio) {
    AudioUnitRenderActionFlags flags = 0;
    checkResult(AudioUnitRender(THIS->_audioUnit, &flags, time, 0, frames, audio), "AudioUnitRender");
    THIS->_outputIsSilence = (flags & kAudioUnitRenderAction_OutputIsSilence);
    return noErr;
}

-(AEAudioControllerRenderCallback)renderCallback {
    return renderCallback; // return our subclass render callback
}

static void notifyModulationStopped(AEAudioController *audioController, void *userInfo, int length) {
    AEGameSoundChannel *THIS = (__bridge AEGameSoundChannel*)*(void**)userInfo;
    if(   ! THIS->_needToAddSelfAsTimingReceiver
       && ! THIS->_modulateVolume.active
       && ! THIS->_modulatePan.active
       && ! THIS->_modulatePitchBend.active) {
        THIS->_needToAddSelfAsTimingReceiver = YES;
        [audioController removeTimingReceiver:THIS];
    }
}

static void timingReceiver(__unsafe_unretained AEGameSoundChannel *THIS,
                           __unsafe_unretained AEAudioController *audioController,
                           const AudioTimeStamp     *time,
                           UInt32 const              frames,
                           AEAudioTimingContext      context) {
    
    // This gets called just before every render cycle
    if(context == AEAudioTimingContextOutput) {
        
        // Volume modulation
        BOOL anyActive = NO;
        if(THIS->_modulateVolume.active) {
            anyActive = YES;
            if(time->mHostTime >= THIS->_modulateVolume.hostEndTime) {
                THIS->_modulateVolume.active = NO;
                if(noErr==AudioUnitSetParameter(THIS->_audioUnit, kAUGroupParameterID_Volume, kAudioUnitScope_Group, 0, THIS->_modulateVolume.endValue, 0)) {
                    THIS->_auVolume = MAX(0.0,MIN(127.0,(float)THIS->_modulateVolume.endValue)) / 127.0;
                }
            } else {
                float percComplete = ((float)(time->mHostTime - THIS->_modulateVolume.hostStartTime)) / THIS->_modulateVolume.hostDuration;
                AudioUnitParameterValue newValue = THIS->_modulateVolume.startValue + (percComplete * THIS->_modulateVolume.valueDiff);
                if(noErr==AudioUnitSetParameter(THIS->_audioUnit, kAUGroupParameterID_Volume, kAudioUnitScope_Group, 0, newValue, 0)) {
                    THIS->_auVolume = MAX(0.0,MIN(127.0,(float)newValue)) / 127.0;
                }
            }
        }
        
        // Pan modulation
        if(THIS->_modulatePan.active) {
            anyActive = YES;
            if(time->mHostTime >= THIS->_modulatePan.hostEndTime) {
                THIS->_modulatePan.active = NO;
                if(noErr==AudioUnitSetParameter(THIS->_audioUnit, kAUGroupParameterID_Pan, kAudioUnitScope_Group, 0, THIS->_modulatePan.endValue, 0)) {
                    THIS->_auPan = ((MAX(0.0,MIN(127.0,(float)THIS->_modulatePan.endValue)) / 127.0) * 2.0) - 1.0;
                }
            } else {
                float percComplete = ((float)(time->mHostTime - THIS->_modulatePan.hostStartTime)) / THIS->_modulatePan.hostDuration;
                AudioUnitParameterValue newValue = THIS->_modulatePan.startValue + (percComplete * THIS->_modulatePan.valueDiff);
                if(noErr==AudioUnitSetParameter(THIS->_audioUnit, kAUGroupParameterID_Pan, kAudioUnitScope_Group, 0, newValue, 0)) {
                    THIS->_auPan = ((MAX(0.0,MIN(127.0,(float)newValue)) / 127.0) * 2.0) - 1.0;
                }
            }
        }
        
        // Pitch modulation
        if(THIS->_modulatePitchBend.active) {
            anyActive = YES;
            if(time->mHostTime >= THIS->_modulatePitchBend.hostEndTime) {
                THIS->_modulatePitchBend.active = NO;
                if(noErr==AudioUnitSetParameter(THIS->_audioUnit, kAUGroupParameterID_PitchBend, kAudioUnitScope_Group, 0, THIS->_modulatePitchBend.endValue, 0)) {
                    THIS->_auPitchBend = (MAX(0.0,MIN(127.0,(float)THIS->_modulatePitchBend.endValue)) / 127.0) * 2.0;
                }
            } else {
                float percComplete = ((float)(time->mHostTime - THIS->_modulatePitchBend.hostStartTime)) / THIS->_modulatePitchBend.hostDuration;
                AudioUnitParameterValue newValue = THIS->_modulatePitchBend.startValue + (percComplete * THIS->_modulatePitchBend.valueDiff);
                if(noErr==AudioUnitSetParameter(THIS->_audioUnit, kAUGroupParameterID_PitchBend, kAudioUnitScope_Group, 0, newValue, 0)) {
                    THIS->_auPitchBend = (MAX(0.0,MIN(127.0,(float)newValue)) / 127.0) * 2.0;
                }
            }
        }
        
        // If not modulating, stop receiving timing info
        if(!anyActive) {
            AEAudioControllerSendAsynchronousMessageToMainThread(audioController, notifyModulationStopped, &THIS, sizeof(AEGameSoundChannel*));
        }
    }
}

- (AEAudioControllerTimingCallback)timingReceiverCallback {
    return timingReceiver;
}

- (void)didRecreateGraph:(NSNotification*)notification {
    _modulatePan.active = NO;
    _modulatePitchBend.active = NO;
    _modulateVolume.active = NO;
    if(!_needToAddSelfAsTimingReceiver) {
        _needToAddSelfAsTimingReceiver = YES;
        [_audioController removeTimingReceiver:self];
    }
    [super didRecreateGraph:notification];
}



-(void)dealloc {
    if(!_needToAddSelfAsTimingReceiver) {
        [_audioController removeTimingReceiver:self];
    }
}

@end
