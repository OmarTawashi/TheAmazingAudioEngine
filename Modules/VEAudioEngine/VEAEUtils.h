//
//  VEAEUtils.h
//  VEAudioEngine Module for TheAmazingAudioEngine
//
//  Created by Leo Thiessen on 2015-01-21.
//
//  Copyright (C) 2015 Visions Encoded.
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

// Include this file only once.
#ifndef VEAEUtils_h_INCLUDED
#define VEAEUtils_h_INCLUDED
#import "VELib3_C.h" // EXTERN_C_BEGIN/END and some math functions and such.
EXTERN_C_BEGIN
    
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "TheAmazingAudioEngine.h"



//---------------------------------------------------------------------------------------------------------------------
#pragma mark - Macros

#if defined(DEBUG) && (DEBUG)
    #define VEAE_IS_DEBUG 1
    #define VEAELog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
    #define VEAE_IS_DEBUG 0
    #define VEAELog(fmt, ...) // OUTPUT NOTHING
#endif


#define audCheck(result,operation) (_audCheckOSStatus((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))



//---------------------------------------------------------------------------------------------------------------------
#pragma mark - C Functions

/// If VEAE_IS_DEBUG then log available AudioUnit parameters in the kAudioUnitScope_Global to the console.
void audLogAUParameters(AudioUnit au);


/// If VEAE_IS_DEBUG then log available AudioUnit parameters in specified scope (e.g. kAudioUnitScope_Global).
void audLogAUParametersInScope(AudioUnit au,
                               int auScope);


/// Get the AudioComponentDescription from an AudioUnit instance.
AudioComponentDescription audGetAUComponentDescription(AudioUnit au);


/// Create a new TAAE channel filter configured with an AUVarispeed Audio Unit, ready to be added and used.
/// @param audioController is the controller this filter will be used with
/// @param cents is in the range of +/-2400
AEAudioUnitFilter* audNewAUVarispeedFilter(AEAudioController *audioController,
                                           int16_t cents);


/// Create a new TAAE channel filter configured with an AUNewTimePitch Audio Unit, ready to be added and used.
/// @param audioController is the controller this filter will be used with
/// @param rate is in the range of 1/32 to 32.0
/// @param cents is in the range of +/-2400
AEAudioUnitFilter* audNewAUNewTimePitchFilter(AEAudioController *audioController,
                                              float rate,
                                              int16_t cents);



//---------------------------------------------------------------------------------------------------------------------
#pragma mark - Static Inline C Functions

/// You can use the audCheck(result, operation) macro instead of calling this function directly.
static inline BOOL _audCheckOSStatus(OSStatus result, const char *operation, const char *file, int line) {
    if(result == noErr) {
        return YES; // is OK
    } else {
        #if (VEAE_IS_DEBUG)
            int fourCC = CFSwapInt32HostToBig(result);
            NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&fourCC);
        #endif
        return NO;
    }
}


/// A simple gain filter for an audio buffer - gain must be >= 0 and should probably be <= 1.0 (max is not enforced)
/// Uses a "linear" algorithm.
static inline void audDSP_gain(AudioBufferList *bufferList,
                               const vDSP_Length frameCount,
                               const float gain) {
    if(gain < 0 || ((int)(gain * 1000)) == 1000) { // amplifying >1.0 is allowed
        return; // nothing to do
    }
    for(UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; ++bufferIndex) {
        vDSP_vsmul((float*)bufferList->mBuffers[bufferIndex].mData, 1, &gain,
                   (float*)bufferList->mBuffers[bufferIndex].mData, 1, frameCount);
    }
}


/// A simple pan filter for an audio buffer - pan must be >= 0.0 (fully left) and <= 2.0 (fully right)
/// Uses a "Sinusoidal" panning algorithm - see http://folk.ntnu.no/oyvinbra/gdsp/Lesson1Panning.html
static inline void audDSP_pan(AudioBufferList *bufferList,
                              const vDSP_Length frameCount,
                              const float pan) {
    if(bufferList->mNumberBuffers < 2) {
        return; // nothing to do
    }
    // Sinusoidal algorithm
    const float f = (pan < 0 ? 0 : (pan > 2 ? 2.0f : pan)) * M_PI_4; // same result as normalized pan value * (PI / 2)
    const float gainLeft = cos(f);
    const float gainRight = sin(f);
    for(UInt32 bufferIndex = 0; (bufferIndex + 1) < bufferList->mNumberBuffers; ++bufferIndex) { // stereo pairs
        vDSP_vsmul((float*)bufferList->mBuffers[bufferIndex].mData, 1, &gainLeft,
                   (float*)bufferList->mBuffers[bufferIndex].mData, 1, frameCount);
        bufferIndex++;
        vDSP_vsmul((float*)bufferList->mBuffers[bufferIndex].mData, 1, &gainRight,
                   (float*)bufferList->mBuffers[bufferIndex].mData, 1, frameCount);
    }

}


/// Utility to create NSError objects.
static inline NSError* audNSError(const OSStatus result,
                                  const NSString *localizedDescription) {
    return [NSError errorWithDomain:NSOSStatusErrorDomain
                               code:result
                           userInfo:@{NSLocalizedDescriptionKey:localizedDescription}];
}



EXTERN_C_END
#endif // VEAEUtils_h_INCLUDED