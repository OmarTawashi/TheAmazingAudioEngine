//
//  AEBlockTimer.m
//  The Amazing Audio Engine
//
//  Based on TPPreciseTimer.m which was created by Michael Tyson on 06/09/2011.
//  Copyright 2011 A Tasty Pixel. All rights reserved.
//
//  This file was created by Leo Thiessen on 12/12/2014.
//

#import "AEBlockTimer.h"
#import <mach/mach_time.h>
#import <pthread.h>

#define kSpinLockTime 0.01

static AEBlockTimer *__sharedInstance = nil;

static const int kBlockIndex = 0;
static const int kDelayIndex = 1;
static const int kTimeIndex  = 2;

@interface AEBlockTimer ()
- (void)scheduleBlock:(ae_timer_block_t)block inTimeInterval:(NSTimeInterval)timeInterval;
- (void)addSchedule:(NSArray*)schedule;
void thread_signal(int signal);
void *thread_entry(void* argument);
- (void)thread;
@end

@implementation AEBlockTimer {
    double timebase_ratio;
    
    NSMutableArray *events;
    NSCondition *condition;
    pthread_t thread;
    
    unsigned long _eventsCount;
}

+ (void)scheduleBlock:(ae_timer_block_t)block inTimeInterval:(NSTimeInterval)timeInterval {
    if ( !__sharedInstance ) __sharedInstance = [[AEBlockTimer alloc] init];
    [__sharedInstance scheduleBlock:block inTimeInterval:timeInterval];
}

- (id)init {
    if ( !(self = [super init]) ) return nil;
    
    struct mach_timebase_info timebase;
    mach_timebase_info(&timebase);
    timebase_ratio = ((double)timebase.numer / (double)timebase.denom) * 1.0e-9;
    
    _eventsCount = 0;
    events = [[NSMutableArray alloc] init];
    condition = [[NSCondition alloc] init];
    
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    pthread_attr_setschedparam(&attr, &param);
    pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
    pthread_create(&thread, &attr, thread_entry, (__bridge void*)self);
    
    return self;
}

- (void)scheduleBlock:(ae_timer_block_t)block inTimeInterval:(NSTimeInterval)timeInterval {
    [self addSchedule:[NSMutableArray arrayWithObjects:
                       [block copy],
                       [NSNumber numberWithDouble:timeInterval],
                       [NSNumber numberWithUnsignedLongLong:mach_absolute_time() + (timeInterval / timebase_ratio)],
                       nil]];
}

- (void)addSchedule:(NSArray*)schedule {
    [condition lock];
    [events addObject:schedule];
    _eventsCount = [events count];
    [events sortUsingComparator:^(id obj1, id obj2) {
        if([[(NSArray*)obj2 objectAtIndex:kTimeIndex] unsignedLongLongValue] < [[(NSArray*)obj1 objectAtIndex:kTimeIndex] unsignedLongLongValue]) {
            return NSOrderedDescending;
        } else {
            return NSOrderedAscending;
        }
    }];
    BOOL mustSignal = _eventsCount > 1 && [events objectAtIndex:0] == schedule;
    [condition signal];
    [condition unlock];
    if ( mustSignal ) {
        pthread_kill(thread, SIGALRM); // Interrupt thread if it's performing a mach_wait_until and new schedule is earlier
    }
}

void *thread_entry(void* argument) {
    [(__bridge AEBlockTimer*)argument thread];
    return NULL;
}

void thread_signal(int signal) {
    // Ignore
}

- (void)thread {
    signal(SIGALRM, thread_signal);
    [condition lock];

    while ( 1 ) {
        while ( _eventsCount == 0 ) {
            [condition wait];
        }
        @autoreleasepool {
            NSMutableArray *nextEvent = [events objectAtIndex:0];
            NSTimeInterval time = [[nextEvent objectAtIndex:kTimeIndex] unsignedLongLongValue] * timebase_ratio;
            
            [condition unlock];
            
            mach_wait_until((uint64_t)((time - kSpinLockTime) / timebase_ratio));
            
            if ( (double)(mach_absolute_time() * timebase_ratio) >= time-kSpinLockTime ) {
                
                // Spin lock until it's time
                uint64_t end = time / timebase_ratio;
                while ( mach_absolute_time() < end );
                
                // Perform action
                ae_timer_block_t block = [nextEvent objectAtIndex:kBlockIndex];
                BOOL shouldRemove = NO;
                if ( block ) {
                    if((shouldRemove=block())) {
                        // finished!
                    } else {
                        double timeInterval = [[nextEvent objectAtIndex:kDelayIndex] doubleValue];
                        unsigned long long nextTime = mach_absolute_time() + (timeInterval / timebase_ratio);
                        [nextEvent replaceObjectAtIndex:kTimeIndex withObject:[NSNumber numberWithUnsignedLongLong:nextTime]];
                        if(_eventsCount>1) {
                            int insertIndex = 0;
                            for(int i = 1; i<_eventsCount; ++i) {
                                if([[[events objectAtIndex:i] objectAtIndex:kDelayIndex] unsignedLongLongValue] > nextTime) {
                                    break; // we've found where it's supposed to be
                                }
                                insertIndex++;
                            }
                            if(insertIndex>0) {
                                // we need to re-shuffle
                                [events removeObjectAtIndex:0];
                                [events insertObject:nextEvent atIndex:insertIndex];
                            }
                        }
                    }
                } else {
                    // no block? remove it
                    shouldRemove = YES;
                }
                
                [condition lock];
                if(shouldRemove) {
                    [events removeObject:nextEvent];
                    _eventsCount = [events count];
                }
            } else {
                [condition lock];
            }
        
        } // END @autoreleasepool
    }
}

@end
