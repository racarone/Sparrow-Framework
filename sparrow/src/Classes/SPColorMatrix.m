//
//  SPColorMatrix.m
//  Sparrow
//
//  Created by Robert Carone on 1/10/14.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPColorMatrix.h"
#import "SPMacros.h"

typedef float Matrix4x5[20];

static const Matrix4x5 Matrix4x5Identity = {
    1,0,0,0,0,
    0,1,0,0,0,
    0,0,1,0,0,
    0,0,0,1,0
};

static const float LUMA_R = 0.299f;
static const float LUMA_G = 0.587f;
static const float LUMA_B = 0.114f;

// --- class implementation ------------------------------------------------------------------------

@implementation SPColorMatrix

// --- c functions ---

static void concatMatrix(SPColorMatrix *self, Matrix4x5 mtx)
{
    int i = 0;
    Matrix4x5 temp;

    for (int y = 0; y < 4; ++y)
    {
        for (int x = 0; x < 5; ++x)
        {
            temp[i+x] = mtx[i]   * self->_m[x] +
                        mtx[i+1] * self->_m[x+ 5] +
                        mtx[i+2] * self->_m[x+10] +
                        mtx[i+3] * self->_m[x+15] + (x == 4 ? mtx[i + 4] : 0);
        }
        i += 5;
    }

    memmove(self->_m, temp, sizeof(Matrix4x5));
}

#pragma mark Initialization

- (instancetype)initWithValues:(const float[20])values
{
    if ((self = [super init]))
    {
        memcpy(_m, values, sizeof(Matrix4x5));
    }
    return self;
}

- (instancetype)init
{
    return [self initWithValues:Matrix4x5Identity];
}

+ (instancetype)colorMatrixWithValues:(const float [20])values
{
    return [[[[self class] allocWithZone:nil] initWithValues:values] autorelease];
}

+ (instancetype)colorMatrixWithIdentity
{
    return [[[[self class] allocWithZone:nil] init] autorelease];
}

#pragma mark Methods

- (void)invert
{
    Matrix4x5 mtx = {
        -1, 0,  0,  0, 255,
        0, -1,  0,  0, 255,
        0,  0, -1,  0, 255,
        0,  0,  0,  1,   0
    };

    concatMatrix(self, mtx);
}

- (void)adjustSaturation:(float)saturation
{
    saturation += 1.0f;

    float invSat  = 1.0f - saturation;
    float invLumR = invSat * LUMA_R;
    float invLumG = invSat * LUMA_G;
    float invLumB = invSat * LUMA_B;

    Matrix4x5 mtx = {
        (invLumR + saturation),  invLumG,               invLumB,               0, 0,
        invLumR,                (invLumG + saturation), invLumB,               0, 0,
        invLumR,                 invLumG,              (invLumB + saturation), 0, 0,
        0,                       0,                     0,                     1, 0
    };

    concatMatrix(self, mtx);
}

- (void)adjustContrast:(float)contrast
{
    float s = contrast + 1.0f;
    float o = 128 * (1.0f - s);

    Matrix4x5 mtx = {
        s, 0, 0, 0, o,
        0, s, 0, 0, o,
        0, 0, s, 0, o,
        0, 0, 0, s, 0
    };

    concatMatrix(self, mtx);
}

- (void)adjustBrightness:(float)brightness
{
    brightness *= 255;

    Matrix4x5 mtx = {
        1, 0, 0, 0, brightness,
        0, 1, 0, 0, brightness,
        0, 0, 1, 0, brightness,
        0, 0, 0, 1, 0
    };

    concatMatrix(self, mtx);
}

- (void)adjustHue:(float)hue
{
    hue *= PI;

    float cos = cosf(hue);
    float sin = sinf(hue);

    Matrix4x5 mtx = {
        // r1
        ((LUMA_R + (cos * (1.0f - LUMA_R))) + (sin * -(LUMA_R))),
        ((LUMA_G + (cos * -(LUMA_G))) + (sin * -(LUMA_G))),
        ((LUMA_B + (cos * -(LUMA_B))) + (sin * (1.0f - LUMA_B))),
        0.0f,
        0.0f,

        // r2
        ((LUMA_R + (cos * -(LUMA_R))) + (sin * 0.143f)),
        ((LUMA_G + (cos * (1.0f - LUMA_G))) + (sin * 0.14f)),
        ((LUMA_B + (cos * -(LUMA_B))) + (sin * -0.283f)),
        0.0f,
        0.0f,

        // r3
        ((LUMA_R + (cos * -(LUMA_R))) + (sin * -((1.0f - LUMA_R)))),
        ((LUMA_G + (cos * -(LUMA_G))) + (sin * LUMA_G)),
        ((LUMA_B + (cos * (1.0f - LUMA_B))) + (sin * LUMA_B)),
        0.0f,
        0.0f,

        // r4
        0.0f,
        0.0f,
        0.0f,
        1.0f,
        0.0f
    };

    concatMatrix(self, mtx);
}

- (void)identity
{
    memcpy(_m, Matrix4x5Identity, sizeof(Matrix4x5));
}

- (void)concatColorMatrix:(SPColorMatrix *)colorMatrix
{
    concatMatrix(self, colorMatrix->_m);
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithValues:_m];
}

#pragma mark Properties

- (float *)values
{
    return _m;
}

- (int)numValues
{
    return 20;
}

@end
