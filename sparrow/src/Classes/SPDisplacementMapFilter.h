//
//  SPDisplacementMapFilter.h
//  Sparrow
//
//  Created by Robert Carone on 10/10/13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPFragmentFilter.h>

@class SPPoint;

// Color Channel
typedef NS_ENUM(uint, SPColorChannel)
{
    SPColorChannelRed,
    SPColorChannelGreen,
    SPColorChannelBlue,
    SPColorChannelAlpha,
};

/** ------------------------------------------------------------------------------------------------

 The SPDisplacementMapFilter class uses the pixel values from the specified texture (called the 
 displacement map) to perform a displacement of an object. You can use this filter to apply a warped 
 or mottled effect to any object that inherits from the DisplayObject class.

 The filter uses the following formula:
 
     dstPixel[x, y] = srcPixel[x + ((componentX(x, y) - 128) * scaleX) / 256,
                               y + ((componentY(x, y) - 128) * scaleY) / 256]

------------------------------------------------------------------------------------------------- */

@interface SPDisplacementMapFilter : SPFragmentFilter

/// --------------------
/// @name Initialization
/// --------------------

/// Intializes the displacement map filter with the specified map texture.
- (instancetype)initWithMapTexture:(SPTexture *)mapTexture;

/// Factory method.
+ (instancetype)displacementMapFilterWithMapTexture:(SPTexture *)texture;

/// ----------------
/// @name Properties
/// ----------------

/// Describes which color channel to use in the map image to displace the x result.
@property (nonatomic, assign) SPColorChannel componentX;

/// Describes which color channel to use in the map image to displace the y result.
@property (nonatomic, assign) SPColorChannel componentY;

/// The multiplier used to scale the x displacement result from the map calculation.
@property (nonatomic, assign) float scaleX;

/// The multiplier used to scale the y displacement result from the map calculation.
@property (nonatomic, assign) float scaleY;

/// The texture that will be used to calculate displacement.
@property (nonatomic, retain) SPTexture* mapTexture;

/// A value that contains the offset of the upper-left corner of the target display object from the
/// upper-left corner of the map image.
@property (nonatomic, copy) SPPoint* mapPoint;

/// Indicates how the pixels at the edge of the input image (the filtered object) will be wrapped
/// at the edge.
@property (nonatomic, assign) BOOL repeat;

@end
