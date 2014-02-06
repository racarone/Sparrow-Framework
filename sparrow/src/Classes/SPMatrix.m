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

#import <Sparrow/SPMacros.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPPoint.h>

// --- class implementation ------------------------------------------------------------------------

@implementation SPMatrix

// --- c functions ---

static inline void setValues(SPMatrix *matrix, float a, float b, float c, float d, float tx, float ty)
{
    matrix->_a = a;
    matrix->_b = b;
    matrix->_c = c;
    matrix->_d = d;
    matrix->_tx = tx;
    matrix->_ty = ty;    
}

#pragma mark Initialization

- (instancetype)initWithA:(float)a b:(float)b c:(float)c d:(float)d tx:(float)tx ty:(float)ty
{
    if (self)
    {
        _a = a; _b = b; _c = c; _d = d;
        _tx = tx; _ty = ty;
    }

    return self;
}

- (instancetype)init
{
    return [self initWithA:1 b:0 c:0 d:1 tx:0 ty:0];
}

+ (instancetype)matrixWithA:(float)a b:(float)b c:(float)c d:(float)d tx:(float)tx ty:(float)ty
{
    return [[[self allocWithZone:nil] initWithA:a b:b c:c d:d tx:tx ty:ty] autorelease];
}

+ (instancetype)matrixWithIdentity
{
    return [[[self allocWithZone:nil] init] autorelease];
}

#pragma mark Methods

- (void)setA:(float)a b:(float)b c:(float)c d:(float)d tx:(float)tx ty:(float)ty
{
    _a = a; _b = b; _c = c; _d = d;
    _tx = tx; _ty = ty;
}

- (BOOL)isEqualToMatrix:(SPMatrix *)matrix
{
    if (matrix == self) return YES;
    else if (!matrix) return NO;
    else
    {
        return SP_IS_FLOAT_EQUAL(_a, matrix->_a) && SP_IS_FLOAT_EQUAL(_b, matrix->_b) &&
               SP_IS_FLOAT_EQUAL(_c, matrix->_c) && SP_IS_FLOAT_EQUAL(_d, matrix->_d) &&
               SP_IS_FLOAT_EQUAL(_tx, matrix->_tx) && SP_IS_FLOAT_EQUAL(_ty, matrix->_ty);
    }
}

- (void)appendMatrix:(SPMatrix *)lhs
{
    setValues(self, lhs->_a * _a  + lhs->_c * _b, 
                    lhs->_b * _a  + lhs->_d * _b, 
                    lhs->_a * _c  + lhs->_c * _d,
                    lhs->_b * _c  + lhs->_d * _d,
                    lhs->_a * _tx + lhs->_c * _ty + lhs->_tx,
                    lhs->_b * _tx + lhs->_d * _ty + lhs->_ty);
}

- (void)prependMatrix:(SPMatrix *)rhs
{
    setValues(self, _a * rhs->_a + _c * rhs->_b,
                    _b * rhs->_a + _d * rhs->_b,
                    _a * rhs->_c + _c * rhs->_d,
                    _b * rhs->_c + _d * rhs->_d,
                    _tx + _a * rhs->_tx + _c * rhs->_ty,
                    _ty + _b * rhs->_tx + _d * rhs->_ty);
}

- (void)translateXBy:(float)dx yBy:(float)dy
{
    _tx += dx;
    _ty += dy;    
}

- (void)scaleXBy:(float)sx yBy:(float)sy
{
    if (sx != 1.0f)
    {
        _a  *= sx;
        _c  *= sx;
        _tx *= sx;
    }
    
    if (sy != 1.0f)
    {
        _b  *= sy;
        _d  *= sy;
        _ty *= sy;
    }
}

- (void)scaleBy:(float)scale
{
    [self scaleXBy:scale yBy:scale];
}

- (void)rotateBy:(float)angle
{
    if (angle == 0.0f) return;
    
    float cos = cosf(angle);
    float sin = sinf(angle);
    
    setValues(self,  _a * cos -  _b * sin,  _a * sin +  _b * cos,
                     _c * cos -  _d * sin,  _c * sin +  _d * cos,
                    _tx * cos - _ty * sin, _tx * sin + _ty * cos);
}

- (void)skewXBy:(float)sx yBy:(float)sy
{
    float sinX = sinf(sx);
    float cosX = cosf(sx);
    float sinY = sinf(sy);
    float cosY = cosf(sy);
    
    setValues(self, _a  * cosY - _b  * sinX,
                    _a  * sinY + _b  * cosX,
                    _c  * cosY - _d  * sinX,
                    _c  * sinY + _d  * cosX,
                    _tx * cosY - _ty * sinX,
                    _tx * sinY + _ty * cosX);
}

- (void)identity
{
    setValues(self, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f);
}

- (void)invert
{
    float det = self.determinant;
    setValues(self, _d/det, -_b/det, -_c/det, _a/det, (_c*_ty-_d*_tx)/det, (_b*_tx-_a*_ty)/det);
}

- (void)copyFromMatrix:(SPMatrix *)matrix
{
    memcpy(&_a, &matrix->_a, sizeof(float) * 6);
}

- (GLKMatrix4)convertToGLKMatrix4
{
    GLKMatrix4 matrix = GLKMatrix4Identity;
    
    matrix.m00 = _a;
    matrix.m01 = _b;
    matrix.m10 = _c;
    matrix.m11 = _d;
    matrix.m30 = _tx;
    matrix.m31 = _ty;
    
    return matrix;
}

- (GLKMatrix3)convertToGLKMatrix3
{
    return GLKMatrix3Make(_a,  _b,  0.0f,
                          _c,  _d,  0.0f,
                          _tx, _ty, 1.0f);
}

- (SPPoint *)transformPoint:(SPPoint *)point
{
    return [SPPoint pointWithX:_a*point.x + _c*point.y + _tx
                             y:_b*point.x + _d*point.y + _ty];
}

- (SPPoint *)transformPointWithX:(float)x y:(float)y
{
    return [SPPoint pointWithX:_a*x + _c*y + _tx
                             y:_b*x + _d*y + _ty];
}

#pragma mark NSObject

- (BOOL)isEqual:(id)object
{
    if (!object)
        return NO;
    else if (object == self)
        return YES;
    else if (![object isKindOfClass:[SPMatrix class]])
        return NO;
    else
        return [self isEqualToMatrix:object];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[SPMatrix: a=%f, b=%f, c=%f, d=%f, tx=%f, ty=%f]", 
            _a, _b, _c, _d, _tx, _ty];
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithA:_a b:_b c:_c d:_d 
                                                     tx:_tx ty:_ty];
}

#pragma mark Properties

- (float)determinant
{
    return _a * _d - _c * _b;
}

- (float)rotation
{
    return atan2f(_b, _a);
}

- (float)scaleX
{
    return _a / cosf(self.skewY);
}

- (float)scaleY
{
    return _d / cosf(self.skewX);
}

- (float)skewX
{
    return atanf(-_c / _d);
}

- (float)skewY
{
    return atanf( _b / _a);
}

@end
