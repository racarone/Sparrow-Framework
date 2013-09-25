//
//  SPMatrix.m
//  Sparrow
//
//  Created by Daniel Sperl on 26.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPMacros.h"
#import "SPMatrix.h"
#import "SPMatrix_Internal.h"
#import "SPPoint.h"

typedef id(*SPMatrixAllocIMP)(id,SEL);

static id               __SPMatrixAllocClass;
static SEL              __SPMatrixAllocSEL;
static SPMatrixAllocIMP __SPMatrixAllocIMP;

SPMatrix* SPMatrixAlloc(void)
{
    return __SPMatrixAllocIMP(__SPMatrixAllocClass, __SPMatrixAllocSEL);
}

// --- class implementation ------------------------------------------------------------------------

@implementation SPMatrix

@synthesize a=_a, b=_b, c=_c, d=_d, tx=_tx, ty=_ty;

+ (void)initialize
{
    __SPMatrixAllocClass    = self;
    __SPMatrixAllocSEL      = @selector(alloc);
    __SPMatrixAllocIMP      = (SPMatrixAllocIMP)[self methodForSelector:__SPMatrixAllocSEL];
}

- (id)initWithA:(float)a b:(float)b c:(float)c d:(float)d tx:(float)tx ty:(float)ty
{
    SPMatrixSet(self, a, b, c, d, tx, ty);
    return self;
}

- (id)init
{
    SPMatrixIdentity(self);
    return self;
}

- (void)setA:(float)a b:(float)b c:(float)c d:(float)d tx:(float)tx ty:(float)ty
{
    SPMatrixSet(self, a, b, c, d, tx, ty);
}

- (float)determinant
{
    return SPMatrixGetDeterminant(self);
}

- (void)appendMatrix:(SPMatrix*)lhs
{
    SPMatrixAppendMatrix(self, lhs);
}

- (void)prependMatrix:(SPMatrix*)rhs
{
    SPMatrixPrependMatrix(self, rhs);
}

- (void)translateXBy:(float)dx yBy:(float)dy
{
    SPMatrixTranslateBy(self, dx, dy);
}

- (void)scaleXBy:(float)sx yBy:(float)sy
{
    SPMatrixScaleBy(self, sx, sy);
}

- (void)scaleBy:(float)scale
{
    SPMatrixScale(self, scale);
}

- (void)rotateBy:(float)angle
{
    SPMatrixRotateBy(self, angle);
}

- (void)skewXBy:(float)sx yBy:(float)sy
{
    SPMatrixSkewBy(self, sx, sy);
}

- (void)identity
{
    SPMatrixIdentity(self);
}

- (SPPoint*)transformPoint:(SPPoint*)point
{
    return SPMatrixTransformPoint(self, point);
}

- (SPPoint*)transformPointWithX:(float)x y:(float)y
{
    return SPMatrixTransformPointWith(self, x, y);
}

- (void)invert
{
    SPMatrixInvert(self);
}

- (void)copyFromMatrix:(SPMatrix*)matrix
{
    SPMatrixCopyFrom(self, matrix);
}

- (GLKMatrix4)convertToGLKMatrix4
{
    return SPMatrixConvertToGLKMatrix4(self);
}

- (GLKMatrix3)convertToGLKMatrix3
{
    return SPMatrixConvertToGLKMatrix3(self);
}

- (BOOL)isEquivalent:(SPMatrix*)other
{
    return SPMatrixIsEquivilant(self, other);
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"[SPMatrix: a=%f, b=%f, c=%f, d=%f, tx=%f, ty=%f]", 
            _a, _b, _c, _d, _tx, _ty];
}

+ (id)matrixWithA:(float)a b:(float)b c:(float)c d:(float)d tx:(float)tx ty:(float)ty
{
    return [[[self alloc] initWithA:a b:b c:c d:d tx:tx ty:ty] autorelease];
}

+ (id)matrixWithIdentity
{
    return [[[self alloc] init] autorelease];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone*)zone
{
    return [[[self class] allocWithZone:zone] initWithA:_a b:_b c:_c d:_d 
                                                     tx:_tx ty:_ty];
}

#pragma mark SPPoolObject

SP_IMPLEMENT_MEMORY_POOL();

@end
