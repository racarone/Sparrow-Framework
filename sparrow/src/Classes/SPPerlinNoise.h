//
//  SPPerlinNoise.h
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>

@interface SPPerlinNoise : NSObject

/// -----------------
/// @name Intializers
/// -----------------

/// Initializes a perlin noise object with the supplied amount of octaves, zoom and persistence.
/// _Designated Initializer_.
- (instancetype)initWithOctaves:(int)octaves zoom:(float)zoom persistence:(float)persistence;

/// Initializes a perlin noise object with the supplied amount of octaves, zoom. Persistence is 1.0f.
- (instancetype)initWithOctaves:(int)octaves zoom:(float)zoom;

/// Initializes a perlin noise object with the supplied amount of octaves. Zoom and Persistence are 1.0f.
- (instancetype)initWithOctaves:(int)octaves;

/// Factory method.
+ (instancetype)perlinNoiseWithOctaves:(int)octaves;

/// Factory method.
+ (instancetype)perlinNoiseWithOctaves:(int)octaves zoom:(float)zoom;

/// Factory method.
+ (instancetype)perlinNoiseWithOctaves:(int)octaves zoom:(float)zoom persistence:(float)persistence;

/// Factory method.
+ (instancetype)perlinNoise;

/// -------------
/// @name Methods
/// -------------

/// Returns a 2D perlin noise value.
- (float)perlinNoiseAtX:(float)x atY:(float)y;

/// Returns a 3D perlin noise value.
- (float)perlinNoiseAtX:(float)x atY:(float)y atZ:(float)z;

/// Returns a 4D perlin noise value.
- (float)perlinNoiseAtX:(float)x atY:(float)y atZ:(float)z atT:(float)t;

/// ----------------
/// @name Properties
/// ----------------

/// The amount of octaves to smooth the noise.
@property (nonatomic, assign) int octaves;

/// Modifies the amplitude of the noise.
@property (nonatomic, assign) float persistence;

/// Modifies the frequency of the noise.
@property (nonatomic, assign) float zoom;

@end
