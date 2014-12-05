//
//  AEMacOSAudioSessionAdapter.m
//  The Amazing Audio Engine
//

#import "AEMacOSAudioSessionAdapter.h"


NSString *const AVAudioSessionCategoryPlayback      = @"AVAudioSessionCategoryPlayback";
NSString *const AVAudioSessionCategoryRecord        = @"AVAudioSessionCategoryRecord";
NSString *const AVAudioSessionCategoryPlayAndRecord = @"AVAudioSessionCategoryPlayAndRecord";

NSString *const AVAudioSessionModeDefault     = @"AVAudioSessionModeDefault";
NSString *const AVAudioSessionModeMeasurement = @"AVAudioSessionModeMeasurement";


@implementation AVAudioSession


+ (AVAudioSession*)sharedInstance
{
    static AVAudioSession *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AVAudioSession alloc] init];
    });
    return sharedInstance;
}


- (BOOL)setActive:(BOOL)active error:(NSError**)outError
{
    return YES;
}


- (BOOL)setCategory:(NSString*)category error:(NSError**)outError
{
    return [self setCategory:category withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:outError];
}


- (BOOL)setCategory:(NSString*)category withOptions:(AVAudioSessionCategoryOptions)options error:(NSError**)outError
{
    return YES;
}


- (BOOL)setMode:(NSString*)mode error:(NSError**)outError
{
    return YES;
}


- (BOOL)setPreferredIOBufferDuration:(NSTimeInterval)duration error:(NSError**)outError;
{
    return YES;
}


- (BOOL)setInputGain:(float)gain  error:(NSError**)outError
{
    return YES;
}

@end