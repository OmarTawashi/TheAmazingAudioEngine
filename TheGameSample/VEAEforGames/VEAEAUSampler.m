//
//  VEAEAUSampler.m
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

#import "VEAEAUSampler.h"
#import "VEMIDI_C_Lib.h"

#define checkResult(result,operation) (_checkResult((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _checkResult(OSStatus result, const char *operation, const char* file, int line) {
    if ( result != noErr ) {
        #if defined(DEBUG) && DEBUG
            int fourCC = CFSwapInt32HostToBig(result);
            NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&fourCC);
        #endif
        return NO;
    }
    return YES;
}

@implementation VEAEAUSampler

@synthesize aupreset = _aupreset;
@synthesize outputIsSilence = _outputIsSilence;

- (instancetype)initWithFileURL:(NSURL*)aupresetFileURL
                audioController:(AEAudioController*)audioController
                          error:(NSError**)error {
    return [self initWithFileURL:aupresetFileURL audioController:audioController preInitializeBlock:NULL error:error];
}

- (instancetype)initWithFileURL:(NSURL*)aupresetFileURL
                audioController:(AEAudioController*)audioController
             preInitializeBlock:(void(^)(AudioUnit audioUnit))block
                          error:(NSError**)error {
    return [self initWithDictionary:[NSMutableDictionary dictionaryWithContentsOfURL:aupresetFileURL] audioController:audioController preInitializeBlock:block error:error];
}

- (id)initWithDictionary:(NSDictionary*)aupresetDictionary
         audioController:(AEAudioController*)audioController
      preInitializeBlock:(void(^)(AudioUnit audioUnit))block
                   error:(NSError**)error {
    
    if(!(aupresetDictionary)) return nil;
    
    if ( !(self = [super init]) ) return nil;
    
    // Create the node, and the audio unit
    _aupreset = aupresetDictionary;
    _audioController = audioController;
    _componentDescription = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple, kAudioUnitType_MusicDevice, kAudioUnitSubType_Sampler);
    _audioGraph = _audioController.audioGraph;
    _outputIsSilence = YES;
    
    if ( ![self setup:block error:error] ) {
        return nil;
    }
    
    self.volume = 1.0;
    self.pan = 0.0;
    self.channelIsMuted = NO;
    self.channelIsPlaying = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRecreateGraph:) name:AEAudioControllerDidRecreateGraphNotification object:_audioController];
    
    return self;
}

- (BOOL)setup:(void(^)(AudioUnit audioUnit))block error:(NSError**)error {
    
    if( !(_aupreset) ) {
        if ( error ) *error = [NSError errorWithDomain:@"nil for required object" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Couldn't initialise audio unit: missing the aupreset"}];
        return NO;
    }
    
    OSStatus result;
    if ( !checkResult(result=AUGraphAddNode(_audioGraph, &_componentDescription, &_node), "AUGraphAddNode") ||
         !checkResult(result=AUGraphNodeInfo(_audioGraph, _node, NULL, &_audioUnit), "AUGraphNodeInfo") ) {
        if ( error ) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result userInfo:@{NSLocalizedDescriptionKey: @"Couldn't initialise audio unit"}];
        return NO;
    }
    
    UInt32 maxFPS = 4096;
    checkResult(result=AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, sizeof(maxFPS)), "kAudioUnitProperty_MaximumFramesPerSlice");

    // Try to set the output audio description
    AudioStreamBasicDescription outASBD = _audioController.audioDescription;
    result = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &outASBD, sizeof(AudioStreamBasicDescription));
    
    checkResult(AUGraphUpdate(_audioGraph, NULL), "AUGraphUpdate");
    
    // Convert the data object into a property list
    CFPropertyListRef presetPropertyList = (__bridge CFPropertyListRef)(_aupreset);
    
    // Set the class info property for the Sampler unit using the property list as the value.
    checkResult(AudioUnitSetProperty(_audioUnit,
                                     kAudioUnitProperty_ClassInfo,
                                     kAudioUnitScope_Global,
                                     0,
                                     &presetPropertyList,
                                     sizeof(CFPropertyListRef)
                                     ),"AudioUnitSetProperty(kAudioUnitProperty_ClassInfo) failed (setting the .aupreset on an AUSampler instance failed)");
    
    if(block) block(_audioUnit);

    checkResult(AudioUnitInitialize(_audioUnit), "AudioUnitInitialize");

    return YES;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AEAudioControllerDidRecreateGraphNotification object:_audioController];
    
    if ( _node ) {
        checkResult(AUGraphRemoveNode(_audioGraph, _node), "AUGraphRemoveNode");
    }

    checkResult(AUGraphUpdate(_audioGraph, NULL), "AUGraphUpdate");
}

-(AudioUnit)audioUnit {
    return _audioUnit;
}

-(AUNode)audioGraphNode {
    return _node;
}

static OSStatus renderCallback(__unsafe_unretained VEAEAUSampler *THIS,
                               __unsafe_unretained AEAudioController *audioController,
                               const AudioTimeStamp     *time,
                               UInt32                    frames,
                               AudioBufferList          *audio) {
    
    AudioUnitRenderActionFlags flags = 0;
    checkResult(AudioUnitRender(THIS->_audioUnit, &flags, time, 0, frames, audio), "AudioUnitRender");
    THIS->_outputIsSilence = (flags & kAudioUnitRenderAction_OutputIsSilence);
    return noErr;
}

- (AEAudioControllerRenderCallback)renderCallback {
    return renderCallback;
}

- (void)didRecreateGraph:(NSNotification*)notification {
    _outputIsSilence = YES;
    _node = 0;
    _audioUnit = NULL;
    _audioGraph = _audioController.audioGraph;
    [self setup:nil error:NULL];
}



#pragma mark - Declared Functions

- (void)startNote:(uint8_t)note withVelocity:(uint8_t)velocity {
    midiNoteOn(_audioUnit, note, velocity);
}

- (void)stopNote:(uint8_t)note {
    midiNoteOff(_audioUnit, note);
}

- (void)sendController:(uint8_t)controller withValue:(uint8_t)value {
    midiSendController(_audioUnit, controller, value);
}

- (void)sendPitchBend:(uint16_t)bendValue {
    midiSendPitchBend(_audioUnit, bendValue);
}

- (void)allNotesOff {
    midiAllNotesOff(_audioUnit);
}

- (void)allSoundOff {
    midiAllSoundOff(_audioUnit);
}

- (void)resetAllControllers {
    midiResetAllControllers(_audioUnit);
}

- (void)panic {
    midiAllNotesOff(_audioUnit);
    midiAllSoundOff(_audioUnit);
    midiResetAllControllers(_audioUnit);
}

@end
