//
//  SPPoint.m
//  Sparrow
//
//  Created by Daniel Sperl on 23.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPPoint.h"
#import "SPPoint_Internal.h"
#import "SPMacros.h"
#import <math.h>

typedef id(*SPPointAllocIMP)(id,SEL);

static id               __SPPointAllocClass;
static SEL              __SPPointAllocSEL;
static SPPointAllocIMP  __SPPointAllocIMP;

SPPoint* SPPointAlloc(void)
{
    return __SPPointAllocIMP(__SPPointAllocClass, __SPPointAllocSEL);
}

// --- class implementation ------------------------------------------------------------------------

@implementation SPPoint

@synthesize x = _x;
@synthesize y = _y;

+ (void)initialize
{
    __SPPointAllocClass = self;
    __SPPointAllocSEL = @selector(alloc);
    __SPPointAllocIMP = (SPPointAllocIMP)[self methodForSelector:__SPPointAllocSEL];
}

// designated initializer
- (id)initWithX:(float)x y:(float)y
{
    _x = x;
    _y = y;
    return self;
}

- (id)initWithPolarLength:(float)length angle:(float)angle
{
    return [self initWithX:cosf(angle)*length y:sinf(angle)*length];
}

- (id)init
{
    return [self initWithX:0.0f y:0.0f];
}

- (float)length
{
    return SPPointGetLength(self);
}

- (float)lengthSquared 
{
    return SPPointGetLengthSquared(self);
}

- (float)angle
{
    return SPPointGetAngle(self);
}

- (BOOL)isOrigin
{
    return SPPointIsOrigin(self);
}

- (SPPoint*)invert
{
    return SPPointInvert(self);
}

- (SPPoint*)addPoint:(SPPoint*)point
{
    return SPPointAddPoint(self, point);
}

- (SPPoint*)subtractPoint:(SPPoint*)point
{
    return SPPointSubtractPoint(self, point);
}

- (SPPoint*)scaleBy:(float)scalar
{
    return SPPointScaleBy(self, scalar);
}

- (SPPoint*)rotateBy:(float)angle  
{
    return SPPointRotateBy(self, angle);
}

- (SPPoint*)normalize
{
    if (_x == 0 && _y == 0)
        [NSException raise:SP_EXC_INVALID_OPERATION format:@"Cannot normalize point in the origin"];

    return SPPointNormalize(self);
}

- (float)dot:(SPPoint*)other
{
    return SPPointDot(self, other);
}

- (void)copyFromPoint:(SPPoint*)point
{
    return SPPointCopyFromPoint(self, point);
}

- (void)setX:(float)x y:(float)y
{
    SPPointSet(self, x, y);
}

- (GLKVector2)convertToGLKVector
{
    return SPPointConvertToGLKVector2(self);
}

- (BOOL)isEquivalent:(SPPoint*)other
{
    return SPPointIsEquivalent(self, other);
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"[SPPoint: x=%f, y=%f]", _x, _y];
}

+ (float)distanceFromPoint:(SPPoint*)p1 toPoint:(SPPoint*)p2
{
    return SPPointDistanceFromPoints(p1, p2);
}

+ (SPPoint*)interpolateFromPoint:(SPPoint*)p1 toPoint:(SPPoint*)p2 ratio:(float)ratio
{
    return SPPointInterpolateFromPoints(p1, p2, ratio);
}

+ (float)angleBetweenPoint:(SPPoint*)p1 andPoint:(SPPoint*)p2
{
    return SPPointAngleBetweenPoints(p1, p2);
}

+ (id)pointWithPolarLength:(float)length angle:(float)angle
{
    return [[[self alloc] initWithPolarLength:length angle:angle] autorelease];
}

+ (id)pointWithX:(float)x y:(float)y
{
    return [[[self alloc] initWithX:x y:y] autorelease];
}

+ (id)point
{
    return [[[self alloc] init] autorelease];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    return [[[self class] allocWithZone:zone] initWithX:_x y:_y];
}

#pragma mark SPPoolObject

SP_IMPLEMENT_MEMORY_POOL();

@end
