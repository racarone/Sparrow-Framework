//
//  SPStage.m
//  Sparrow
//
//  Created by Daniel Sperl on 15.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPDisplayObject_Internal.h"
#import "SPDisplayObjectContainer_Internal.h"
#import "SPEnterFrameEvent.h"
#import "SPMacros.h"
#import "SPRenderSupport.h"
#import "SPStage_Internal.h"

#ifdef SP_TARGET_IPHONE
    #import <UIKit/UIKit.h>
    #define MAIN_SCREEN_SIZE() [UIScreen mainScreen].bounds.size
#else
    #import <Cocoa/Cocoa.h>
    #define MAIN_SCREEN_SIZE() [NSScreen mainScreen].frame.size
#endif

// --- class implementation ------------------------------------------------------------------------

@implementation SPStage
{
    float           _width;
    float           _height;
    uint            _color;
    NSMutableArray* _enterFrameListeners;
}

@synthesize width   = _width;
@synthesize height  = _height;
@synthesize color   = _color;

- (instancetype)initWithWidth:(float)width height:(float)height
{    
    if ((self = [super init]))
    {
        _width = width;
        _height = height;
        _enterFrameListeners = [[NSMutableArray alloc] init];
    }
    return self;
}

- (instancetype)init
{
    CGSize screenSize = MAIN_SCREEN_SIZE();
    return [self initWithWidth:screenSize.width height:screenSize.height];
}

- (void)dealloc
{
    SP_RELEASE_AND_NIL(_enterFrameListeners);

    [super dealloc];
}

- (void)advanceTime:(double)seconds
{
    SPEnterFrameEvent* enterFrameEvent = [[SPEnterFrameEvent alloc]initWithType:kSPEventTypeEnterFrame passedTime:seconds];
    [self broadcastEvent:enterFrameEvent];
    [enterFrameEvent release];
}

- (SPDisplayObject*)hitTestPoint:(SPPoint*)localPoint
{
    if (!self.visible || !self.touchable)
        return nil;
    
    // if nothing else is hit, the stage returns itself as target
    SPDisplayObject* target = [super hitTestPoint:localPoint];
    if (!target) target = self;
    
    return target;
}

- (void)render:(SPRenderSupport*)support
{
    [SPRenderSupport clearWithColor:_color alpha:1.0f];
    [support setupOrthographicProjectionWithLeft:0 right:_width top:0 bottom:_height];
    
    [super render:support];
}

- (void)setX:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot set x-coordinate of stage"];
}

- (void)setY:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot set y-coordinate of stage"];
}

- (void)setPivotX:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot set pivot coordinates of stage"];
}

- (void)setPivotY:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot set pivot coordinates of stage"];
}

- (void)setScaleX:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot scale stage"];
}

- (void)setScaleY:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot scale stage"];
}

- (void)setSkewX:(float)skewX
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot skew stage"];
}

- (void)setSkewY:(float)skewY
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot skew stage"];
}

- (void)setRotation:(float)value
{
    [NSException raise:SP_EXC_INVALID_OPERATION format:@"cannot rotate stage"];
}

@end

// -------------------------------------------------------------------------------------------------

@implementation SPStage (Internal)

- (void)addEnterFrameListener:(SPDisplayObject*)listener
{
    [_enterFrameListeners addObject:listener];
}

- (void)removeEnterFrameListener:(SPDisplayObject*)listener
{
    NSUInteger index = [_enterFrameListeners indexOfObject:listener];
    if (index != NSNotFound) [_enterFrameListeners removeObjectAtIndex:index];
}

- (void)getChildEventListeners:(SPDisplayObject*)object eventType:(NSString*)type listeners:(NSMutableArray*)listeners
{
    if ([type isEqualToString:kSPEventTypeEnterFrame] && object == self)
        [listeners addObjectsFromArray:_enterFrameListeners];
    else
        [super getChildEventListeners:object eventType:type listeners:listeners];
}

@end
