//
//  SPTouch.m
//  Sparrow
//
//  Created by Daniel Sperl on 01.05.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPDisplayObjectContainer.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPTouch.h>
#import <Sparrow/SPTouch_Internal.h>

@implementation SPTouch
{
    double _timestamp;
    float _globalX;
    float _globalY;
    float _previousGlobalX;
    float _previousGlobalY;
    int _tapCount;
    SPTouchPhase _phase;
    SPDisplayObject *_target;
    size_t _touchID;
}

#pragma mark Initialization

- (instancetype)initWithID:(size_t)touchID
{
    if (self = [super init])
        _touchID = touchID;

    return self;
}

- (instancetype)init
{
    return [self initWithID:0];
}

- (void)dealloc
{
    [_target release];
    [super dealloc];
}

+ (instancetype)touchWithID:(size_t)touchID
{
    return [[[self alloc] initWithID:touchID] autorelease];
}

+ (instancetype)touch
{
    return [[[self alloc] init] autorelease];
}

#pragma mark Methods

- (SPPoint *)locationInSpace:(SPDisplayObject *)space
{
    SPMatrix *transformationMatrix = [_target.root transformationMatrixToSpace:space];
    return [transformationMatrix transformPointWithX:_globalX y:_globalY];
}

- (SPPoint *)previousLocationInSpace:(SPDisplayObject *)space
{
    SPMatrix *transformationMatrix = [_target.root transformationMatrixToSpace:space];
    return [transformationMatrix transformPointWithX:_previousGlobalX y:_previousGlobalY];
}

- (SPPoint *)movementInSpace:(SPDisplayObject *)space
{
    SPMatrix *transformationMatrix = [_target.root transformationMatrixToSpace:space];
    SPPoint *curLoc = [transformationMatrix transformPointWithX:_globalX y:_globalY];
    SPPoint *preLoc = [transformationMatrix transformPointWithX:_previousGlobalX y:_previousGlobalY];
    return [curLoc subtractPoint:preLoc];
}

- (BOOL)isTouchingTarget:(SPDisplayObject *)target
{
    return target == _target || ([target isKindOfClass:[SPDisplayObjectContainer class]] &&
                                 [(SPDisplayObjectContainer *)target containsChild:_target]);
}

#pragma mark NSObject

- (NSUInteger)hash
{
    return _touchID;
}

- (BOOL)isEqualTo:(id)object
{
    if (!object)
        return NO;
    else if (object == self)
        return YES;
    else if ([object isKindOfClass:[SPTouch class]])
        return [object touchID] == _touchID;

    return NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[SPTouch: globalX=%.1f, globalY=%.1f, phase=%d, tapCount=%d]",
            _globalX, _globalY, _phase, _tapCount];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    SPTouch *clone = [[SPTouch alloc] initWithID:_touchID];
    clone->_globalX = _globalX;
    clone->_globalY = _globalY;
    clone->_previousGlobalX = _previousGlobalX;
    clone->_previousGlobalY = _previousGlobalY;
    clone->_phase = _phase;
    clone->_tapCount = _tapCount;
    clone->_timestamp = _timestamp;
    clone->_target = [_target retain];
    return clone;
}

@end
