//
//  SPDelayedInvocation.m
//  Sparrow
//
//  Created by Daniel Sperl on 11.07.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPDelayedInvocation.h"

@implementation SPDelayedInvocation
{
    id _target;

    int _repeatCount;
    double _totalTime;
    double _currentTime;
    
    SPCallbackBlock _block;
    NSMutableArray *_invocations;
}

#pragma mark Initialization

- (instancetype)initWithTarget:(id)target delay:(double)time block:(SPCallbackBlock)block
{
    if (!target && !block)
        [NSException raise:SPExceptionInvalidOperation format:@"Target and block cannot both be nil"];

    if ((self = [super init]))
    {
        _totalTime = MAX(0.0001, time); // zero is not allowed
        _currentTime = 0;
        _block = [block copy];
        _repeatCount = 1;
        
        if (target)
        {
            _target = [target retain];
            _invocations = [[NSMutableArray alloc] init];
        }
    }
    return self;
}

- (instancetype)initWithTarget:(id)target delay:(double)time
{
    return [self initWithTarget:target delay:time block:nil];
}

- (instancetype)initWithDelay:(double)time block:(SPCallbackBlock)block
{
    return [self initWithTarget:nil delay:time block:block];
}

- (instancetype)init
{
    return [self initWithTarget:nil delay:0 block:nil];
}

- (void)dealloc
{
    [_target release];
    [_block release];
    [_invocations release];
    [super dealloc];
}

+ (instancetype)invocationWithTarget:(id)target delay:(double)time
{
    return [[[self alloc] initWithTarget:target delay:time] autorelease];
}

+ (instancetype)invocationWithDelay:(double)time block:(SPCallbackBlock)block
{
    return [[[self alloc] initWithDelay:time block:block] autorelease];
}

#pragma mark NSObject

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

#pragma mark SPAnimatable

- (void)advanceTime:(double)seconds
{
    double previousTime = _currentTime;
    _currentTime = MIN(_totalTime, _currentTime + seconds);

    if (previousTime < _totalTime && _currentTime >= _totalTime)
    {
        if (_repeatCount == 0 || _repeatCount > 1)
        {
            [self invoke];

            if (_repeatCount > 0) --_repeatCount;
            _currentTime = 0;

            [self advanceTime:(previousTime + _currentTime) - _totalTime];
        }
        else
        {
            [self invoke];
            [self dispatchEventWithType:SPEventTypeRemoveFromJuggler];
        }
    }
}

#pragma mark Properties

- (BOOL)isComplete
{
    return _repeatCount == 1 && _currentTime >= _totalTime;
}

#pragma mark Private

- (void)invoke
{
    if (_invocations) [_invocations makeObjectsPerformSelector:@selector(invoke)];
    if (_block) _block();
}

@end
