//
//  SPTouch.m
//  Sparrow
//
//  Created by Daniel Sperl on 01.05.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPDisplayObject.h>
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

- (instancetype)init
{
    return [super init];
}

- (void)dealloc
{
    [_target release];
    [super dealloc];
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

#pragma mark NSObject

- (NSUInteger)hash
{
    return _touchID;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[SPTouch: globalX=%.1f, globalY=%.1f, phase=%d, tapCount=%d]",
            _globalX, _globalY, _phase, _tapCount];
}

@end

// -------------------------------------------------------------------------------------------------

@implementation SPTouch (Internal)

- (void)setTimestamp:(double)timestamp
{
    _timestamp = timestamp;
}

- (void)setGlobalX:(float)x
{
    _globalX = x;
}

- (void)setGlobalY:(float)y
{
    _globalY = y;
}

- (void)setPreviousGlobalX:(float)x
{
    _previousGlobalX = x;
}

- (void)setPreviousGlobalY:(float)y
{
    _previousGlobalY = y;
}

- (void)setTapCount:(int)tapCount
{
    _tapCount = tapCount;
}

- (void)setPhase:(SPTouchPhase)phase
{
    _phase = phase;
}

- (void)setTarget:(SPDisplayObject *)target
{
    SP_RELEASE_AND_RETAIN(_target, target);
}

+ (SPTouch *)touch
{
    return [[[SPTouch alloc] init] autorelease];
}

- (void)setTouchID:(size_t)touchID
{
    _touchID = touchID;
}

- (size_t)touchID
{
    return _touchID;
}

@end
