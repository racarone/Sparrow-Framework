//
//  SPPerlinNoise.m
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPMacros.h"
#import "SPPerlinNoise.h"

#define PERMUTATION_SIZE 256

static const char GRADIENT[32][4] = {
    { 1,  1,  1, 0}, { 1,  1, 0,  1}, { 1, 0,  1,  1}, { 0,  1,  1,  1},
    { 1,  1, -1, 0}, { 1,  1, 0, -1}, { 1, 0,  1, -1}, { 0,  1,  1, -1},
    { 1, -1,  1, 0}, { 1, -1, 0,  1}, { 1, 0, -1,  1}, { 0,  1, -1,  1},
    { 1, -1, -1, 0}, { 1, -1, 0, -1}, { 1, 0, -1, -1}, { 0,  1, -1, -1},
    {-1,  1,  1, 0}, {-1,  1, 0,  1}, {-1, 0,  1,  1}, { 0, -1,  1,  1},
    {-1,  1, -1, 0}, {-1,  1, 0, -1}, {-1, 0,  1, -1}, { 0, -1,  1, -1},
    {-1, -1,  1, 0}, {-1, -1, 0,  1}, {-1, 0, -1,  1}, { 0, -1, -1,  1},
    {-1, -1, -1, 0}, {-1, -1, 0, -1}, {-1, 0, -1, -1}, { 0, -1, -1, -1},
};

// --- C functions ---------------------------------------------------------------------------------

SP_INLINE float productOf(float a, float b)
{
    if (b > 0)
        return a;
    if (b < 0)
        return -a;
    return 0;
}

SP_INLINE float dotProduct(float x0, float x1, float y0, float y1, float z0, float z1, float t0, float t1)
{
    return productOf(x0, x1) + productOf(y0, y1) + productOf(z0, z1) + productOf(t0, t1);
}

SP_INLINE float spline(float state)
{
    const float square = state * state;
    const float cubic = square * state;
    return cubic * (6 * square - 15 * state + 10);
}

SP_INLINE float interpolate(float a, float b, float t)
{
    return a + (t * (b - a));
}

// --- class implementation ------------------------------------------------------------------------

@implementation SPPerlinNoise
{
    int _permut[PERMUTATION_SIZE];
}

// --- c functions ---

SP_INLINE int gradientAt(SPPerlinNoise* self, int i, int j, int k, int l)
{
    return (self->_permut[(l + self->_permut[(k + self->_permut[(j + self->_permut[i & 0xff])
                                                                & 0xff])
                                             & 0xff])
                          & 0xff]
            & 0x1f);
}

static float smoothNoise(SPPerlinNoise* self, float x, float y, float z, float t)
{
    const int x0 = (int)(x > 0 ? x : x - 1);
    const int y0 = (int)(y > 0 ? y : y - 1);
    const int z0 = (int)(z > 0 ? z : z - 1);
    const int t0 = (int)(t > 0 ? t : t - 1);

    const int x1 = x0+1;
    const int y1 = y0+1;
    const int z1 = z0+1;
    const int t1 = t0+1;

    // The vectors
    float dx0 = x-x0;
    float dy0 = y-y0;
    float dz0 = z-z0;
    float dt0 = t-t0;
    const float dx1 = x-x1;
    const float dy1 = y-y1;
    const float dz1 = z-z1;
    const float dt1 = t-t1;

    // The 16 gradient values
    const char * g0000 = GRADIENT[gradientAt(self, x0, y0, z0, t0)];
    const char * g0001 = GRADIENT[gradientAt(self, x0, y0, z0, t1)];
    const char * g0010 = GRADIENT[gradientAt(self, x0, y0, z1, t0)];
    const char * g0011 = GRADIENT[gradientAt(self, x0, y0, z1, t1)];
    const char * g0100 = GRADIENT[gradientAt(self, x0, y1, z0, t0)];
    const char * g0101 = GRADIENT[gradientAt(self, x0, y1, z0, t1)];
    const char * g0110 = GRADIENT[gradientAt(self, x0, y1, z1, t0)];
    const char * g0111 = GRADIENT[gradientAt(self, x0, y1, z1, t1)];
    const char * g1000 = GRADIENT[gradientAt(self, x1, y0, z0, t0)];
    const char * g1001 = GRADIENT[gradientAt(self, x1, y0, z0, t1)];
    const char * g1010 = GRADIENT[gradientAt(self, x1, y0, z1, t0)];
    const char * g1011 = GRADIENT[gradientAt(self, x1, y0, z1, t1)];
    const char * g1100 = GRADIENT[gradientAt(self, x1, y1, z0, t0)];
    const char * g1101 = GRADIENT[gradientAt(self, x1, y1, z0, t1)];
    const char * g1110 = GRADIENT[gradientAt(self, x1, y1, z1, t0)];
    const char * g1111 = GRADIENT[gradientAt(self, x1, y1, z1, t1)];

    // The 16 dot products
    const float b0000 = dotProduct(dx0, g0000[0], dy0, g0000[1], dz0, g0000[2], dt0, g0000[3]);
    const float b0001 = dotProduct(dx0, g0001[0], dy0, g0001[1], dz0, g0001[2], dt1, g0001[3]);
    const float b0010 = dotProduct(dx0, g0010[0], dy0, g0010[1], dz1, g0010[2], dt0, g0010[3]);
    const float b0011 = dotProduct(dx0, g0011[0], dy0, g0011[1], dz1, g0011[2], dt1, g0011[3]);
    const float b0100 = dotProduct(dx0, g0100[0], dy1, g0100[1], dz0, g0100[2], dt0, g0100[3]);
    const float b0101 = dotProduct(dx0, g0101[0], dy1, g0101[1], dz0, g0101[2], dt1, g0101[3]);
    const float b0110 = dotProduct(dx0, g0110[0], dy1, g0110[1], dz1, g0110[2], dt0, g0110[3]);
    const float b0111 = dotProduct(dx0, g0111[0], dy1, g0111[1], dz1, g0111[2], dt1, g0111[3]);
    const float b1000 = dotProduct(dx1, g1000[0], dy0, g1000[1], dz0, g1000[2], dt0, g1000[3]);
    const float b1001 = dotProduct(dx1, g1001[0], dy0, g1001[1], dz0, g1001[2], dt1, g1001[3]);
    const float b1010 = dotProduct(dx1, g1010[0], dy0, g1010[1], dz1, g1010[2], dt0, g1010[3]);
    const float b1011 = dotProduct(dx1, g1011[0], dy0, g1011[1], dz1, g1011[2], dt1, g1011[3]);
    const float b1100 = dotProduct(dx1, g1100[0], dy1, g1100[1], dz0, g1100[2], dt0, g1100[3]);
    const float b1101 = dotProduct(dx1, g1101[0], dy1, g1101[1], dz0, g1101[2], dt1, g1101[3]);
    const float b1110 = dotProduct(dx1, g1110[0], dy1, g1110[1], dz1, g1110[2], dt0, g1110[3]);
    const float b1111 = dotProduct(dx1, g1111[0], dy1, g1111[1], dz1, g1111[2], dt1, g1111[3]);

    dx0 = spline(dx0);
    dy0 = spline(dy0);
    dz0 = spline(dz0);
    dt0 = spline(dt0);

    const float b111 = interpolate(b1110, b1111, dt0);
    const float b110 = interpolate(b1100, b1101, dt0);
    const float b101 = interpolate(b1010, b1011, dt0);
    const float b100 = interpolate(b1000, b1001, dt0);
    const float b011 = interpolate(b0110, b0111, dt0);
    const float b010 = interpolate(b0100, b0101, dt0);
    const float b001 = interpolate(b0010, b0011, dt0);
    const float b000 = interpolate(b0000, b0001, dt0);

    const float b11 = interpolate(b110, b111, dz0);
    const float b10 = interpolate(b100, b101, dz0);
    const float b01 = interpolate(b010, b011, dz0);
    const float b00 = interpolate(b000, b001, dz0);

    const float b1 = interpolate(b10, b11, dy0);
    const float b0 = interpolate(b00, b01, dy0);

    const float result = interpolate(b0, b1, dx0);
    
    return result;
}

static float perlinNoise(SPPerlinNoise* self, float x, float y, float z, float t)
{
    float noise = 0.0;
    for (int octave = 0; octave < self->_octaves; octave++)
    {
        float frequency = powf(2, octave);
        float amplitude = powf(self->_persistence, octave);
        noise += smoothNoise(self,
                             x * frequency/self->_zoom,
                             y * frequency/self->_zoom,
                             z * frequency/self->_zoom,
                             t * frequency/self->_zoom) * amplitude;
    }
    return noise;
}

// ---

- (instancetype)initWithOctaves:(int)octaves zoom:(float)zoom persistence:(float)persistence
{
    if ((self = [super init]))
    {
        for (unsigned int i = 0; i < PERMUTATION_SIZE; i++)
            _permut[i] = rand() & 0xff;

        _octaves = octaves;
        _zoom = zoom;
        _persistence = persistence;
    }
    return self;
}

- (instancetype)initWithOctaves:(int)octaves zoom:(float)zoom
{
    return [self initWithOctaves:octaves zoom:zoom persistence:1.0f];
}

- (instancetype)initWithOctaves:(int)octaves
{
    return [self initWithOctaves:octaves zoom:1.0f];
}

- (instancetype)init
{
    return [self initWithOctaves:1];
}

- (float)perlinNoiseAtX:(float)x atY:(float)y atZ:(float)z atT:(float)t
{
    return perlinNoise(self, x, y, z, t);
}

- (float)perlinNoiseAtX:(float)x atY:(float)y atZ:(float)z
{
    return perlinNoise(self, x, y, z, 0.0f);
}

- (float)perlinNoiseAtX:(float)x atY:(float)y
{
    return perlinNoise(self, x, y, 0.0f, 0.0f);
}

+ (instancetype)perlinNoiseWithOctaves:(int)octaves
{
    return [[[self alloc] initWithOctaves:octaves] autorelease];
}

+ (instancetype)perlinNoiseWithOctaves:(int)octaves zoom:(float)zoom
{
    return [[[self alloc] initWithOctaves:octaves zoom:zoom] autorelease];
}

+ (instancetype)perlinNoiseWithOctaves:(int)octaves zoom:(float)zoom persistence:(float)persistence
{
    return [[[self alloc] initWithOctaves:octaves zoom:zoom persistence:persistence] autorelease];
}

+ (instancetype)perlinNoise
{
    return [[[self alloc] init] autorelease];
}

@end
