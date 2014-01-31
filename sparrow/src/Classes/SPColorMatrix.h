//
//  SPColorMatrix.h
//  Sparrow
//
//  Created by Robert Carone on 1/10/14.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <Sparrow/SPPoolObject.h>

/* A color matrix class containing an array of 20 floats arranged as a 4x5 matrix. */

@interface SPColorMatrix : SPPoolObject <NSCopying>
{
  @protected
    float _m[20];
}

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes a color matrix with an array of 20 floats. _Designated Initializer_.
- (instancetype)initWithValues:(const float[20])values;

/// Initializes an identity matrix.
- (instancetype)init;

/// Factory method.
+ (instancetype)colorMatrixWithValues:(const float[20])values;

/// Factory method.
+ (instancetype)colorMatrixWithIdentity;

/// -------------
/// @name Methods
/// -------------

/// Inverts the colors.
- (void)invert;

/// Changes the saturation. Typical values are in the range [-1, 1].
/// Values above zero will raise, values below zero will reduce the saturation.
/// '-1' will produce a grayscale image.
- (void)adjustSaturation:(float)saturation;

/// Changes the contrast. Typical values are in the range [-1, 1].
/// Values above zero will raise, values below zero will reduce the contrast.
- (void)adjustContrast:(float)contrast;

/// Changes the brightness. Typical values are in the range [-1, 1].
/// Values above zero will make the image brighter, values below zero will make it darker.
- (void)adjustBrightness:(float)brightness;

/// Changes the hue. Typical values are in the range [-1, 1].
- (void)adjustHue:(float)hue;

/// Changes the color matrix into an identity matrix.
- (void)identity;

/// Concatenates the receiving color matrix with another one.
- (void)concatColorMatrix:(SPColorMatrix *)colorMatrix;

/// ----------------
/// @name Properties
/// ----------------

/// Returns a point to the internal color matrix array.
@property (nonatomic, readonly) float* values;

/// Returns the count of values (always 20).
@property (nonatomic, readonly) int numValues;

@end
