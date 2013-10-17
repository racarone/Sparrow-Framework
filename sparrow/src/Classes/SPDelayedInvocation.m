//
//  SPDelayedInvocation.m
//  Sparrow
//
//  Created by Daniel Sperl on 11.07.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPDelayedInvocation.h"


@implementation SPDelayedInvocation
{
    id _target;
    double _totalTime;
    double _currentTime;
    
    SPCallbackBlock _block;
    dispatch_queue_t _queue;
    NSMutableArray *_invocations;
}

- (instancetype)initWithTarget:(id)target delay:(double)time block:(SPCallbackBlock)block queue:(dispatch_queue_t)queue
{
    if ((self = [super init]))
    {
        _totalTime = MAX(0.0001, time); // zero is not allowed
        _currentTime = 0;
        _block = [block copy];
        _queue = queue;
        if (_queue) dispatch_retain(queue);

        if (target)
        {
            _target = [target retain];
            _invocations = [[NSMutableArray alloc] init];
        }
    }
    return self;
}

- (instancetype)initWithTarget:(id)target delay:(double)time block:(SPCallbackBlock)block
{
    return [self initWithTarget:target delay:time block:block queue:nil];
}

- (instancetype)initWithTarget:(id)target delay:(double)time
{
    return [self initWithTarget:target delay:time block:NULL];
}

- (instancetype)initWithDelay:(double)time block:(SPCallbackBlock)block queue:(dispatch_queue_t)queue
{
    return [self initWithTarget:nil delay:time block:block queue:queue];
}

- (instancetype)initWithDelay:(double)time block:(SPCallbackBlock)block
{
    return [self initWithTarget:nil delay:time block:block];
}

- (instancetype)init
{
    return nil;
}

- (void)dealloc
{
    if (_queue) dispatch_release(_queue);
    [_block release];
    [_invocations release];
    [_target release];
    [super dealloc];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature *sig = [[self class] instanceMethodSignatureForSelector:aSelector];
    if (!sig) sig = [_target methodSignatureForSelector:aSelector];
    return sig;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    if ([_target respondsToSelector:[anInvocation selector]])
    {
        anInvocation.target = _target;
        [anInvocation retainArguments];
        [_invocations addObject:anInvocation];
    }
}

- (void)advanceTime:(double)seconds
{
    self.currentTime = _currentTime + seconds;
}

- (void)setCurrentTime:(double)currentTime
{
    double previousTime = _currentTime;    
    _currentTime = MIN(_totalTime, currentTime);
    
    if (previousTime < _totalTime && _currentTime >= _totalTime)
    {
        if (_invocations) [_invocations makeObjectsPerformSelector:@selector(invoke)];
        if (_block)
        {
            if (_queue) dispatch_async(_queue, _block);
            else        _block();
        }
        
        [self dispatchEventWithType:SPEventTypeRemoveFromJuggler];
    }
}

- (BOOL)isComplete
{
    return _currentTime >= _totalTime;
}

+ (instancetype)invocationWithTarget:(id)target delay:(double)time
{
    return [[[self alloc] initWithTarget:target delay:time] autorelease];
}

+ (instancetype)invocationWithDelay:(double)time block:(SPCallbackBlock)block
{
    return [[[self alloc] initWithDelay:time block:block] autorelease];
}

+ (instancetype)invocationWithDelay:(double)time block:(SPCallbackBlock)block queue:(dispatch_queue_t)queue
{
    return [[[self alloc] initWithDelay:time block:block queue:queue] autorelease];
}

@end
