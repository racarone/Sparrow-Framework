//
//  SPBlurFilter.h
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPFragmentFilter.h>

/** ------------------------------------------------------------------------------------------------

 The SPBlurFilter applies a gaussian blur to an object. The strength of the blur can be
 set for x- and y-axis separately (always relative to the stage).

 A blur filter can also be set up as a drop shadow or glow filter. Use the respective
 static methods to create such a filter.

 For each blur direction, the number of required passes is ceil(blur).
    blur = 0.5: 1 pass
    blur = 1.0: 1 pass
    blur = 1.5: 2 passes
    blur = 2.0: 2 passes
    etc.

 ------------------------------------------------------------------------------------------------- */

@interface SPBlurFilter : SPFragmentFilter

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes a blur filter with the specified blur and a resolution. _Designated Initializer_.
- (instancetype)initWithBlur:(float)blur resolution:(float)resolution;

/// Initializes a blur filter with the specified blur and a resolution of 1.0f.
- (instancetype)initWithBlur:(float)blur;

/// Initializes a blur filter with a blur and resolution of 1.0f.
- (instancetype)init;

/// Factory method.
+ (instancetype)blurFilterWithBlur:(float)blur resolution:(float)resolution;

/// Factory method.
+ (instancetype)blurFilterWithBlur:(float)blur;

/// Factory method.
+ (instancetype)blurFilter;

/// -----------------
/// @name Drop Shadow
/// -----------------

/// Creates a black drop shadow with a distance of 4.0 at a 45 degree angle.
+ (instancetype)dropShadow;

/// Creates a black drop shadow with a specified distance at a 45 degree angle.
+ (instancetype)dropShadowWithDistance:(float)distance;

/// Creates a black drop shadow with a specified distance and angle.
+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle;

/// Creates a drop shadow with a specified distance, angle and color.
+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color;

/// Creates a drop shadow with a specified distance, angle, color and alpha.
+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color alpha:(float)alpha;

/// Creates a drop shadow with a specified distance, angle, color, alpha and blur.
+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color alpha:(float)alpha blur:(float)blur;

/// Creates a drop shadow with a specified distance, angle, color, alpha, blur and resolution.
+ (instancetype)dropShadowWithDistance:(float)distance angle:(float)angle color:(uint)color alpha:(float)alpha blur:(float)blur resolution:(float)resolution;

/// ----------
/// @name Glow
/// ----------

/// Creates a yellow glow.
+ (instancetype)glow;

/// Creates a glow with a specified color.
+ (instancetype)glowWithColor:(uint)color;

/// Creates a glow with a specified color and alpha.
+ (instancetype)glowWithColor:(uint)color alpha:(float)alpha;

/// Creates a glow with a specified color, alpha and blur.
+ (instancetype)glowWithColor:(uint)color alpha:(float)alpha blur:(float)blur;

/// Creates a glow with a specified color, alpha, blur and resolution.
+ (instancetype)glowWithColor:(uint)color alpha:(float)alpha blur:(float)blur resolution:(float)resolution;

/// -------------
/// @name Methods
/// -------------

/// The current uniform color will replace the RGB values of the input color. Pass NO to deactivate
/// the uniform color.
- (void)setUniformColor:(BOOL)enable;

/// The passed color will replace the RGB values of the input color. Pass NO as the first parameter
/// to deactivate the uniform color.
- (void)setUniformColor:(BOOL)enable color:(uint)color;

/// A uniform color will replace the RGB values of the input color, while the alpha value will be
/// multiplied with the given factor. Pass NO as the first parameter to deactivate the uniform color.
- (void)setUniformColor:(BOOL)enable color:(uint)color alpha:(float)alpha;

/// ----------------
/// @name Properties
/// ----------------

/// The blur factor in x-direction (stage coordinates).
@property (nonatomic, assign) float blurX;

/// The blur factor in y-direction (stage coordinates).
@property (nonatomic, assign) float blurY;

@end
