//
//  AEMacOSAudioSessionAdapter.h
//  The Amazing Audio Engine
//

#ifdef __cplusplus
extern "C" {
#endif

#import <Foundation/Foundation.h>
#import <AVFoundation/AVBase.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>	/* for NSTimeInterval */
#import <AvailabilityMacros.h>
#import <CoreAudio/CoreAudioTypes.h>



#ifndef kAppleSoftwareAudioCodecManufacturer
// From <AudioToolbox/AudioFormat.h> on iOS
enum
{
    kAppleSoftwareAudioCodecManufacturer = 'appl',
    kAppleHardwareAudioCodecManufacturer = 'aphw'
};
#endif

/* This protocol is available with iPhone 3.0 or later */
@protocol AVAudioSessionDelegate;
@class NSError, NSString, NSArray, NSNumber;
@class AVAudioSessionChannelDescription, AVAudioSessionPortDescription, AVAudioSessionRouteDescription, AVAudioSessionDataSourceDescription;

extern NSString *const AVAudioSessionCategoryPlayback;
extern NSString *const AVAudioSessionCategoryRecord;
extern NSString *const AVAudioSessionCategoryPlayAndRecord;

typedef NS_OPTIONS(NSUInteger, AVAudioSessionCategoryOptions)
{
    AVAudioSessionCategoryOptionMixWithOthers    = 1,
    AVAudioSessionCategoryOptionAllowBluetooth   = 4,
    AVAudioSessionCategoryOptionDefaultToSpeaker = 8
};

extern NSString *const AVAudioSessionModeDefault;
extern NSString *const AVAudioSessionModeMeasurement;



@interface AVAudioSession : NSObject

+ (AVAudioSession*)sharedInstance;

- (BOOL)setActive:(BOOL)active error:(NSError**)outError;

- (BOOL)setCategory:(NSString*)category error:(NSError**)outError;
- (BOOL)setCategory:(NSString*)category withOptions:(AVAudioSessionCategoryOptions)options error:(NSError**)outError;
@property(readonly) NSString* category;

@property(readonly) AVAudioSessionCategoryOptions categoryOptions;

- (BOOL)setMode:(NSString*)mode error:(NSError**)outError; /* set session mode */
@property(readonly) NSString* mode; /* get session mode */

//@end
/* AVAudioSessionHardwareConfiguration manages the set of properties that reflect the current state of
 audio hardware in the current route.  Applications whose functionality depends on these properties should
 reevaluate them any time the route changes. */
//@interface AVAudioSession (AVAudioSessionHardwareConfiguration)

- (BOOL)setPreferredIOBufferDuration:(NSTimeInterval)duration error:(NSError**)outError;
@property(readonly) NSTimeInterval preferredIOBufferDuration;
@property(readonly) NSTimeInterval IOBufferDuration;

@property(readonly, getter=isInputAvailable) BOOL inputAvailable;
- (BOOL)setInputGain:(float)gain  error:(NSError**)outError;
@property(readonly) float inputGain; /* value in range [0.0, 1.0] */

@property(readonly, getter=isInputGainSettable) BOOL inputGainSettable;

@property(readonly) NSTimeInterval inputLatency;

@property(readonly) NSTimeInterval outputLatency;


@end
    
#ifdef __cplusplus
}
#endif
