//
//  AEBlockTimer.h
//  The Amazing Game Engine
//
//  Based on TPPreciseTimer.h which was created by Michael Tyson on 06/09/2011.
//  Copyright 2011 A Tasty Pixel. All rights reserved.
//
//  This file was created by Leo Thiessen on 12/12/2014.
//

#import <Foundation/Foundation.h>



/** A block that returns YES when it is finished, or NO if it should be called again. */
typedef BOOL (^ae_timer_block_t)();



@interface AEBlockTimer : NSObject

/**
 * Schedules a block to be called after `timeInterval`.  Your block must return YES when 
 * it is finished.  If you want the block to run repeatedly every time `timeInterval` has
 * elapsed, return NO from the block, until finished (retun YES to finish).
 */
+ (void)scheduleBlock:(ae_timer_block_t)block inTimeInterval:(NSTimeInterval)timeInterval;


@end
