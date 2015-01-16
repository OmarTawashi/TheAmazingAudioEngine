//
//  TPPreciseTimer.m
//  Loopy
//
//  Created by Michael Tyson on 06/09/2011.
//  Copyright 2011 A Tasty Pixel. All rights reserved.
//

#import "TPPreciseTimer.h"
#import <mach/mach_time.h>
#import <pthread.h>

#define kSpinLockTime 0.01

static TPPreciseTimer *__sharedInstance = nil;

static NSString *kTimeKey = @"time";
static NSString *kArgumentKey = @"argument";
static NSString *kBlockKey = @"block";
static NSString *kDelayKey = @"delay";

@interface TPPreciseTimer ()
- (void)scheduleBlock:(tp_timer_block_t)block inTimeInterval:(NSTimeInterval)timeInterval;
- (void)addSchedule:(NSDictionary*)schedule;
void thread_signal(int signal);
void *thread_entry(void* argument);
- (void)thread;
@end

@implementation TPPreciseTimer {
    unsigned long _eventsCount;
}

+ (void)scheduleBlock:(tp_timer_block_t)block inTimeInterval:(NSTimeInterval)timeInterval {
    if ( !__sharedInstance ) __sharedInstance = [[TPPreciseTimer alloc] init];
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

- (void)scheduleBlock:(tp_timer_block_t)block inTimeInterval:(NSTimeInterval)timeInterval {
    [self addSchedule:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                       [block copy],
                       kBlockKey,
                       [NSNumber numberWithUnsignedLongLong:mach_absolute_time() + (timeInterval / timebase_ratio)],
                       kTimeKey,
                       [NSNumber numberWithDouble:timeInterval],
                       kDelayKey,
                       nil]];
}

- (void)addSchedule:(NSDictionary*)schedule {
    [condition lock];
    [events addObject:schedule];
    _eventsCount = [events count];
    [events sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:kTimeKey ascending:YES]]];
    BOOL mustSignal = _eventsCount > 1 && [events objectAtIndex:0] == schedule;
    [condition signal];
    [condition unlock];
    if ( mustSignal ) {
        pthread_kill(thread, SIGALRM); // Interrupt thread if it's performing a mach_wait_until and new schedule is earlier
    }
}

void *thread_entry(void* argument) {
    [(__bridge TPPreciseTimer*)argument thread];
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
            NSMutableDictionary *nextEvent = [events objectAtIndex:0];
            NSTimeInterval time = [[nextEvent objectForKey:kTimeKey] unsignedLongLongValue] * timebase_ratio;
            
            [condition unlock];
            
            mach_wait_until((uint64_t)((time - kSpinLockTime) / timebase_ratio));
            
            if ( (double)(mach_absolute_time() * timebase_ratio) >= time-kSpinLockTime ) {
                
                // Spin lock until it's time
                uint64_t end = time / timebase_ratio;
                while ( mach_absolute_time() < end );
                
                // Perform action
                tp_timer_block_t block = [nextEvent objectForKey:kBlockKey];
                BOOL shouldRemove = NO;
                if ( block ) {
                    if((shouldRemove=block())) {
                        // finished!
                        NSLog(@"Finished block!  ");
                    } else {
                        double timeInterval = [[nextEvent valueForKey:kDelayKey] doubleValue];
                        [nextEvent setValue:[NSNumber numberWithUnsignedLongLong:mach_absolute_time() + (timeInterval / timebase_ratio)] forKey:kTimeKey];
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
