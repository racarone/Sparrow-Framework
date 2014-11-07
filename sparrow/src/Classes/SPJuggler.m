//
//  SPJuggler.m
//  Sparrow
//
//  Created by Daniel Sperl on 09.05.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPAnimatable.h>
#import <Sparrow/SPDelayedInvocation.h>
#import <Sparrow/SPEventDispatcher.h>
#import <Sparrow/SPJuggler.h>
#import <Sparrow/SPTween.h>

@implementation SPJuggler
{
    NSMutableOrderedSet *_objects;
    double _elapsedTime;
    float _speed;
}

#pragma mark Initialization

- (instancetype)init
{    
    if ((self = [super init]))
    {        
        _objects = [[NSMutableOrderedSet alloc] init];
        _elapsedTime = 0.0;
        _speed = 1.0f;
    }
    return self;
}

- (void)dealloc
{
    [_objects release];
    [super dealloc];
}

+ (instancetype)juggler
{
    return [[[SPJuggler alloc] init] autorelease];
}

#pragma mark Methods

- (void)addObject:(id<SPAnimatable>)object
{
    if (object && ![_objects containsObject:object])
    {
        [_objects addObject:object];
        
        if ([(id)object isKindOfClass:[SPEventDispatcher class]])
            [(SPEventDispatcher *)object addEventListener:@selector(onRemove:) atObject:self
                                                  forType:SPEventTypeRemoveFromJuggler];
    }
}

- (void)onRemove:(SPEvent *)event
{
    [self removeObject:(id<SPAnimatable>)[[event.target retain] autorelease]];

    if ([event.target isKindOfClass:[SPTween class]])
    {
        SPTween *tween = (SPTween *)event.target;
        if (tween.isComplete) [self addObject:tween.nextTween];
    }
}

- (void)removeObject:(id<SPAnimatable>)object
{
    [_objects removeObject:object];
    
    if ([(id)object isKindOfClass:[SPEventDispatcher class]])
        [(SPEventDispatcher *)object removeEventListenersAtObject:self
                                     forType:SPEventTypeRemoveFromJuggler];
}

- (void)removeAllObjects
{
    for (id object in _objects)
    {
        if ([(id)object isKindOfClass:[SPEventDispatcher class]])
            [(SPEventDispatcher *)object removeEventListenersAtObject:self
                                         forType:SPEventTypeRemoveFromJuggler];
    }
    
    [_objects removeAllObjects];
}

- (void)removeObjectsWithTarget:(id)object
{
    SEL targetSel = @selector(target);
    NSMutableOrderedSet *remainingObjects = [[NSMutableOrderedSet alloc] init];
    
    for (id currentObject in _objects)
    {
        if (![currentObject respondsToSelector:targetSel] || ![[currentObject target] isEqual:object])
            [remainingObjects addObject:currentObject];
        else if ([(id)currentObject isKindOfClass:[SPEventDispatcher class]])
            [(SPEventDispatcher *)currentObject removeEventListenersAtObject:self
                                                forType:SPEventTypeRemoveFromJuggler];
    }

    SP_RELEASE_AND_RETAIN(_objects, remainingObjects);
    [remainingObjects release];
}

- (BOOL)containsObject:(id<SPAnimatable>)object
{
    return [_objects containsObject:object];
}

- (id)delayInvocationAtTarget:(id)target byTime:(double)time
{
    SPDelayedInvocation *delayedInv = [SPDelayedInvocation invocationWithTarget:target delay:time];
    [self addObject:delayedInv];
    return delayedInv;    
}

- (id)delayInvocationByTime:(double)time block:(SPCallbackBlock)block
{
    SPDelayedInvocation *delayedInv = [SPDelayedInvocation invocationWithDelay:time block:block];
    [self addObject:delayedInv];
    return delayedInv;
}

- (id)tweenWithTarget:(id)target time:(double)time properties:(NSDictionary *)properties
{
    SPTween *tween = [SPTween tweenWithTarget:target time:time];

    for (NSString *property in properties)
    {
        id value = properties[property];
        SEL selector = NSSelectorFromString(property);

        if ([tween respondsToSelector:selector])
            [tween setValue:value forKey:property];
        else if ([target respondsToSelector:selector])
            [tween animateProperty:property targetValue:[value floatValue]];
        else
            [NSException raise:SPExceptionInvalidOperation format:@"Invalid property %@", property];
    }

    [self addObject:tween];
    return tween;
}

#pragma mark SPAnimatable

- (void)advanceTime:(double)seconds
{
    if (seconds < 0.0)
        [NSException raise:SPExceptionInvalidOperation format:@"time must be positive"];

    seconds *= _speed;

    if (seconds > 0.0)
    {
        _elapsedTime += seconds;

        // we need work with a copy, since user-code could modify the collection while enumerating
        NSArray* objectsCopy = [[_objects array] copy];

        for (id<SPAnimatable> object in objectsCopy)
            [object advanceTime:seconds];

        [objectsCopy release];
    }
}

#pragma mark Properties

- (void)setSpeed:(float)speed
{
    if (speed < 0.0)
        [NSException raise:SPExceptionInvalidOperation format:@"speed must be positive"];
    else
        _speed = speed;
}

@end
