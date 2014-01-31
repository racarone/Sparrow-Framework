//
//  SPSubTexture.h
//  Sparrow
//
//  Created by Daniel Sperl on 27.06.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <Sparrow/SPTexture.h>

@class SPMatrix;

/** ------------------------------------------------------------------------------------------------
 
 An SPSubTexture represents a section of another texture. This is achieved solely by 
 manipulation of texture coordinates, making the class very efficient. 
 
 Note that it is OK to create subtextures of subtextures.
 
------------------------------------------------------------------------------------------------- */

@interface SPSubTexture : SPTexture

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes a subtexture with a region (in points) of another texture, using a frame rectangle
/// to place the texture within an image. If `rotated` is `YES`, the subtexture will show the base
/// region rotated by 90 degrees (CCW). _Designated Initializer_.
- (instancetype)initWithRegion:(SPRectangle *)region frame:(SPRectangle *)frame
                       rotated:(BOOL)rotated ofTexture:(SPTexture *)texture;

/// Initializes a subtexture with a region (in points) of another texture, using a frame rectangle
/// to place the texture within an image.
- (instancetype)initWithRegion:(SPRectangle *)region frame:(SPRectangle *)frame
                     ofTexture:(SPTexture *)texture;

/// Initializes a subtexture with a region (in points) of another texture.
- (instancetype)initWithRegion:(SPRectangle *)region ofTexture:(SPTexture *)texture;

/// Factory method.
+ (instancetype)textureWithRegion:(SPRectangle *)region ofTexture:(SPTexture *)texture;

/// ----------------
/// @name Properties
/// ----------------

/// The texture which the subtexture is based on.
@property (nonatomic, readonly) SPTexture *parent;

/// The clipping rectangle, which is the region provided on initialization, scaled into [0.0, 1.0].
@property (nonatomic, readonly) SPRectangle *clipping;

/// The matrix that is used to transform the texture coordinates into the coordinate
/// space of the parent texture (used internally by the "adjust..."-methods).
/// CAUTION: Use with care! Each call returns the same instance.
@property (nonatomic, readonly) SPMatrix *transformationMatrix;

@end
