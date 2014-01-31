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

#import <Sparrow/SPMacros.h>
#import <Sparrow/SPPoint.h>

// --- class implementation ------------------------------------------------------------------------

@implementation SPPoint

#pragma mark Initialization

- (instancetype)initWithX:(float)x y:(float)y
{
    if ((self = [super init]))
    {
        _x = x;
        _y = y;        
    }
    return self;
}

- (instancetype)initWithPolarLength:(float)length angle:(float)angle
{
    return [self initWithX:cosf(angle)*length y:sinf(angle)*length];
}

- (instancetype)init
{
    return [self initWithX:0.0f y:0.0f];
}

+ (instancetype)pointWithPolarLength:(float)length angle:(float)angle
{
    return [[[self allocWithZone:nil] initWithPolarLength:length angle:angle] autorelease];
}

+ (instancetype)pointWithX:(float)x y:(float)y
{
    return [[[self allocWithZone:nil] initWithX:x y:y] autorelease];
}

+ (instancetype)point
{
    return [[[self allocWithZone:nil] init] autorelease];
}

#pragma mark Methods

- (SPPoint *)addPoint:(SPPoint *)point
{
    return [SPPoint pointWithX:_x+point->_x y:_y+point->_y];
}

- (SPPoint *)subtractPoint:(SPPoint *)point
{
    return [SPPoint pointWithX:_x-point->_x y:_y-point->_y];
}

- (SPPoint *)scaleBy:(float)scalar
{
    return [SPPoint pointWithX:_x * scalar y:_y * scalar];
}

- (SPPoint *)rotateBy:(float)angle  
{
    float sina = sinf(angle);
    float cosa = cosf(angle);
    return [SPPoint pointWithX:(_x * cosa) - (_y * sina) y:(_x * sina) + (_y * cosa)];
}

- (SPPoint *)normalize
{
    if (_x == 0 && _y == 0)
        [NSException raise:SPExceptionInvalidOperation format:@"Cannot normalize point in the origin"];
        
    float inverseLength = 1.0f / self.length;
    return [SPPoint pointWithX:_x * inverseLength y:_y * inverseLength];
}

- (SPPoint *)invert
{
    return [SPPoint pointWithX:-_x y:-_y];
}

- (float)dot:(SPPoint *)other
{
    return _x * other->_x + _y * other->_y;
}

- (BOOL)isEquivalent:(SPPoint *)point
{
    if (point == self) return YES;
    else if (!point) return NO;
    else
    {
        return SP_IS_FLOAT_EQUAL(_x, point->_x) &&
               SP_IS_FLOAT_EQUAL(_y, point->_y);
    }
}

- (void)copyFromPoint:(SPPoint *)point
{
    _x = point->_x;
    _y = point->_y;
}

- (void)setX:(float)x y:(float)y
{
    _x = x;
    _y = y;
}

- (GLKVector2)convertToGLKVector
{
    return GLKVector2Make(_x, _y);
}

+ (float)distanceFromPoint:(SPPoint *)p1 toPoint:(SPPoint *)p2
{
    return sqrtf(SP_SQUARE(p2->_x - p1->_x) + SP_SQUARE(p2->_y - p1->_y));
}

+ (SPPoint *)interpolateFromPoint:(SPPoint *)p1 toPoint:(SPPoint *)p2 ratio:(float)ratio
{
    float invRatio = 1.0f - ratio;
    return [SPPoint pointWithX:invRatio * p1->_x + ratio * p2->_x
                             y:invRatio * p1->_y + ratio * p2->_y];
}

+ (float)angleBetweenPoint:(SPPoint *)p1 andPoint:(SPPoint *)p2
{
    float cos = [p1 dot:p2] / (p1.length * p2.length);
    return cos >= 1.0f ? 0.0f : acosf(cos);
}

#pragma mark NSObject

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;

    if ([object hash] != [self hash])
        return NO;

    if ([object isKindOfClass:[SPPoint class]])
        return [self isEquivalent:object];

    return NO;
}

- (NSUInteger)hash
{
    return (SPHashInt(_x) ^ (SPHashInt(_y) << 1));
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[SPPoint: x=%f, y=%f]", _x, _y];
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithX:_x y:_y];
}

#pragma mark Properties

- (float)length
{
    return sqrtf(SP_SQUARE(_x) + SP_SQUARE(_y));
}

- (float)lengthSquared
{
    return SP_SQUARE(_x) + SP_SQUARE(_y);
}

- (float)angle
{
    return atan2f(_y, _x);
}

- (BOOL)isOrigin
{
    return _x == 0.0f && _y == 0.0f;
}

@end
