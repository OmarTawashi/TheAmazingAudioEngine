//
//  VEAEforGames.m
//  TheGameSample
//
//  Created by Leo on 2014-12-08.
//  Copyright (c) 2014 visionsencoded.com, All rights reserved.
//

#import "VEAEforGames.h"
#import <QuartzCore/QuartzCore.h>



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



#pragma mark - STATIC VARIABLES (used internally to this file)

static AEAudioController *_audCtrlr = nil;
static AEChannelGroupRef _channelGroup = NULL;



#pragma mark - HIDDEN (INTERNAL USE) FUNCTIONS

AudioStreamBasicDescription _audCreateModifiedCopyOfASBD(AudioStreamBasicDescription asbd, float sampleRate, int numChannels) {
    // Create a mono audio description
    asbd.mSampleRate = sampleRate; // I like to use 22050.0 for games
    AEAudioStreamBasicDescriptionSetChannelsPerFrame(&asbd, numChannels); // e.g. 1 for mono
    return asbd;
}




#pragma mark - UTILITY FUNCTIONS







#pragma mark - "GAME ENGINE" INIT

AEAudioController* audInit(AEAudioController *audioControllerOrNil) {
    if(_audCtrlr == nil) {
        
        // Ensure we have an AEAudioController
        _audCtrlr = audioControllerOrNil;
        if(_audCtrlr == nil) {
            // Init audio controller
//            AudioStreamBasicDescription asbd = [AEAudioController nonInterleaved16BitStereoAudioDescription]; // this does not work on Mac
            AudioStreamBasicDescription asbd = [AEAudioController nonInterleavedFloatStereoAudioDescription]; // this works on both Mac & iOS
            _audCtrlr = [[AEAudioController alloc] initWithAudioDescription:_audCreateModifiedCopyOfASBD(asbd, 22050.0, asbd.mChannelsPerFrame)];
            NSError *err;
            if([_audCtrlr start:&err] == NO) {
                NSLog(@"ERROR: Couldn't start the AEAudioController.  Error.debugDescription: %@", [err localizedDescription]);
                [_audCtrlr stop];
                _audCtrlr = nil;
                return nil;
            }
        }
        
    }
    
    // Create our channel group
    if(_channelGroup==NULL) {
        _channelGroup = [_audCtrlr createChannelGroup];
        
    }
    
    return _audCtrlr;
}


AEAudioController* audController() {
    return _audCtrlr;
}


VEAEGameSound* audLoadEffect(NSURL *url, float pitch, BOOL isLooping) {
    if(_audCtrlr) {
        return [[VEAEGameSound alloc] initWithFileURL:url audioController:_audCtrlr shouldLoop:isLooping cents:audPitchToCents(pitch) error:nil];
    } else {
        #if defined(DEBUG) && DEBUG
            NSLog(@"%s:%i:%s() - Audio engine not initialized.", strrchr(__FILE__, '/')+1, __LINE__, __FUNCTION__);
        #endif
        return nil;
    }
}

//void audPlayEffect(VEAEGameSound *sound) {
//    [sound play:1.0];
////    [sound setChannelIsMuted:NO];
////    [sound setChannelIsPlaying:YES];
//}






































