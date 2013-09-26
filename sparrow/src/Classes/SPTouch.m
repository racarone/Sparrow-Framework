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

#import "SPDisplayObject.h"
#import "SPMatrix_Internal.h"
#import "SPPoint.h"
#import "SPTouch.h"
#import "SPTouch_Internal.h"

@implementation SPTouch
{
    double              _timestamp;
    float               _globalX;
    float               _globalY;
    float               _previousGlobalX;
    float               _previousGlobalY;
    int                 _tapCount;
    SPTouchPhase        _phase;
    SPDisplayObject*    _target;
    id                  _nativeTouch;
}

@synthesize timestamp           = _timestamp;
@synthesize globalX             = _globalX;
@synthesize globalY             = _globalY;
@synthesize previousGlobalX     = _previousGlobalX;
@synthesize previousGlobalY     = _previousGlobalY;
@synthesize tapCount            = _tapCount;
@synthesize phase               = _phase;
@synthesize target              = _target;

- (instancetype)init
{
    return [super init];
}

- (void)dealloc
{
    SP_RELEASE_AND_NIL(_nativeTouch);
    [super dealloc];
}

- (SPPoint*)locationInSpace:(SPDisplayObject*)space
{
    SPMatrix* transformationMatrix = [_target.root transformationMatrixToSpace:space];
    return SPMatrixTransformPointWith(transformationMatrix, _globalX, _globalY);
}

- (SPPoint*)previousLocationInSpace:(SPDisplayObject*)space
{
    SPMatrix* transformationMatrix = [_target.root transformationMatrixToSpace:space];
    return SPMatrixTransformPointWith(transformationMatrix, _previousGlobalX, _previousGlobalY);
}

- (SPPoint*)movementInSpace:(SPDisplayObject*)space
{
    SPMatrix* transformationMatrix = [_target.root transformationMatrixToSpace:space];
    SPPoint* curLoc = SPMatrixTransformPointWith(transformationMatrix, _globalX, _globalY);
    SPPoint* preLoc = SPMatrixTransformPointWith(transformationMatrix, _previousGlobalX, _previousGlobalY);
    return SPPointSubtractPoint(curLoc, preLoc);
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"[SPTouch: globalX=%.1f, globalY=%.1f, phase=%u, tapCount=%d]",
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

- (void)setTarget:(SPDisplayObject*)target
{
    if (_target != target)
        _target = target;
}

+ (SPTouch*)touch
{
    return [[[SPTouch alloc] init] autorelease];
}

- (void)setNativeTouch:(id)nativeTouch
{
    SP_ASSIGN_RETAIN(_nativeTouch, nativeTouch);
}

- (instancetype)nativeTouch
{
    return _nativeTouch;
}

@end

