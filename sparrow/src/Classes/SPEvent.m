//
//  SPEvent.m
//  Sparrow
//
//  Created by Daniel Sperl on 27.04.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPEventDispatcher.h"
#import "SPEvent.h"
#import "SPEvent_Internal.h"
#import "SPMacros.h"

// --- event types ---------------------------------------------------------------------------------

NSString *const SPEventTypeAdded                = @"added";
NSString *const SPEventTypeAddedToStage         = @"addedToStage";
NSString *const SPEventTypeRemoved              = @"removed";
NSString *const SPEventTypeRemovedFromStage     = @"removedFromStage";
NSString *const SPEventTypeRemoveFromJuggler    = @"removeFromJuggler";
NSString *const SPEventTypeCompleted            = @"completed";
NSString *const SPEventTypeTriggered            = @"triggered";
NSString *const SPEventTypeFlatten              = @"flatten";

// --- class implementation ------------------------------------------------------------------------

@implementation SPEvent
{
    SPEventDispatcher *__weak _target;
    SPEventDispatcher *__weak _currentTarget;
    NSString *_type;
    BOOL _stopsImmediatePropagation;
    BOOL _stopsPropagation;
    BOOL _bubbles;
}

- (instancetype)initWithType:(NSString*)type bubbles:(BOOL)bubbles
{    
    if ((self = [super init]))
    {        
        _type = [[NSString alloc] initWithString:type];
        _bubbles = bubbles;
    }
    return self;
}

- (instancetype)initWithType:(NSString*)type
{
    return [self initWithType:type bubbles:NO];
}

- (instancetype)init
{
    return [self initWithType:@"undefined"];
}

- (void)dealloc
{
    [_type release];
    [super dealloc];
}

- (void)stopImmediatePropagation
{
    _stopsImmediatePropagation = YES;
}

- (void)stopPropagation
{
    _stopsPropagation = YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@: type=\"%@\", bubbles=%@]",
            NSStringFromClass([self class]), _type, _bubbles ? @"YES" : @"NO"];
}

+ (instancetype)eventWithType:(NSString*)type bubbles:(BOOL)bubbles
{
    return [[[self alloc] initWithType:type bubbles:bubbles] autorelease];
}

+ (instancetype)eventWithType:(NSString*)type
{
    return [[[self alloc] initWithType:type] autorelease];
}


@end

// --- internal implementation ---------------------------------------------------------------------

@implementation SPEvent (Internal)

- (BOOL)stopsImmediatePropagation
{ 
    return _stopsImmediatePropagation;
}

- (BOOL)stopsPropagation
{ 
    return _stopsPropagation;
}

- (void)setTarget:(SPEventDispatcher*)target
{
    if (_target != target)
        _target = target;
}

- (void)setCurrentTarget:(SPEventDispatcher*)currentTarget
{
    if (_currentTarget != currentTarget)
        _currentTarget = currentTarget;
}

@end
