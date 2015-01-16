//
//  TPPreciseTimer.h
//  Loopy
//
//  Created by Michael Tyson on 06/09/2011.
//  Copyright 2011 A Tasty Pixel. All rights reserved.
//

#import <Foundation/Foundation.h>


/** This block type needs to return YES when it is finished, or NO to be called again after the spedified timeInterval */
typedef BOOL (^tp_timer_block_t)();


@interface TPPreciseTimer : NSObject {
    double timebase_ratio;
    
    NSMutableArray *events;
    NSCondition *condition;
    pthread_t thread;
}

+ (void)scheduleBlock:(tp_timer_block_t)block inTimeInterval:(NSTimeInterval)timeInterval;


@end
