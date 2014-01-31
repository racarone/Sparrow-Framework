//
//  SPColorMatrixFilter.h
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPFragmentFilter.h>

@class SPColorMatrix;

/** ------------------------------------------------------------------------------------------------

 The SPColorMatrixFilter class lets you apply a 4x5 matrix transformation on the RGBA color and 
 alpha values of every pixel in the input image to produce a result with a new set of RGBA color and 
 alpha values. It allows saturation changes, hue rotation, luminance to alpha, and various other 
 effects.

 The class contains several convenience methods for frequently used color adjustments. All those 
 methods change the current matrix, which means you can easily combine them in one filter:

    // create an inverted filter with 50% saturation and 180° hue rotation
    SPColorMatrixFilter* filter = [[SPColorMatrixFilter alloc] init]
    [filter invert];
    [filter adjustSaturation:-0.5];
    [filter adjustHue:1.0];

 If you want to gradually animate one of the predefined color adjustments, either reset the matrix 
 after each step, or use an identical adjustment value for each step; the changes will add up.

------------------------------------------------------------------------------------------------- */

@interface SPColorMatrixFilter : SPFragmentFilter

/// --------------------
/// @name Initialization
/// --------------------

/// Initialize a color matrix filter with a color matrix.  _Designated initializer_.
- (instancetype)initWithMatrix:(SPColorMatrix *)colorMatrix;

/// Initialize a color matrix filter with an identity color matrix.
- (instancetype)init;

/// Factory method.
+ (instancetype)colorMatrixFilterWithMatrix:(SPColorMatrix *)colorMatrix;

/// Factory method.
+ (instancetype)colorMatrixFilter;

/// -------------
/// @name Methods
/// -------------

/// Inverts the colors of the filtered objects.
- (void)invert;

/// Changes the saturation. Typical values are in the range(-1, 1). Values above zero will raise,
/// values below zero will reduce the saturation. '-1' will produce a grayscale image.
- (void)adjustSaturation:(float)saturation;

/// Changes the contrast. Typical values are in the range(-1, 1). Values above zero will raise,
/// values below zero will reduce the contrast.
- (void)adjustContrast:(float)contrast;

/// Changes the brightness. Typical values are in the range(-1, 1). Values above zero will make the
/// image brighter, values below zero will make it darker.
- (void)adjustBrightness:(float)brightness;

/// Changes the hue of the image. Typical values are in the range(-1, 1).
- (void)adjustHue:(float)hue;

/// -------------------------
/// @name Matrix Manipulation
/// -------------------------

/// Changes the filter matrix back to the identity matrix.
- (void)reset;

/// Concatenates the current matrix with another one.
- (void)concatColorMatrix:(SPColorMatrix *)colorMatrix;

/// ----------------
/// @name Properties
/// ----------------

/// The color matrix object used to apply the filter.
@property (nonatomic, copy) SPColorMatrix *colorMatrix;

@end
