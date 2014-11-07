//
//  SPGLTexture.h
//  Sparrow
//
//  Created by Daniel Sperl on 27.06.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import <Sparrow/SPTexture.h>

@class SPRectangle;
@class SPPVRData;

typedef struct
{
    SPTextureFormat format;
    float scale;
    int width;
    int height;
    int numMipmaps;
    BOOL generateMipmaps;
    BOOL premultipliedAlpha;
} SPTextureProperties;

/** ------------------------------------------------------------------------------------------------

 The SPGLTexture class is a concrete implementation of the abstract class SPTexture,
 containing a standard 2D OpenGL texture. 
 
 In most cases, you don't have to use this class directly (the init-methods of the SPTexture class
 should suffice for most needs). However, you can use this class in combination with a
 GLKTextureLoader to load types that Sparrow doesn't support itself.
 
------------------------------------------------------------------------------------------------- */

@interface SPGLTexture : SPTexture

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes a texture with the given properties. Width and height are expected pixel dimensions.
/// _Designated Initializer_.
- (instancetype)initWithName:(uint)name format:(SPTextureFormat)format
                       width:(float)width height:(float)height containsMipmaps:(BOOL)mipmaps
                       scale:(float)scale premultipliedAlpha:(BOOL)pma;

/// Initializes an uncompressed texture with with raw pixel data and a set of properties.
/// Width and height are expected pixel dimensions.
- (instancetype)initWithData:(const void *)imgData properties:(SPTextureProperties)properties;

/// Initializes a PVR texture with with a certain scale factor.
- (instancetype)initWithPVRData:(SPPVRData *)pvrData scale:(float)scale;

/// -------------
/// @name Methods
/// -------------

/// Uploads image data.
- (void)uploadData:(const void *)imgData;

/// Uploads pvr image data.
- (void)uploadPVRData:(SPPVRData *)data;

/// Clears the texture. The previous contents of the texture is wiped out.
- (void)clear;

/// Clears the texture with a certain color. The previous contents of the texture is wiped out.
- (void)clearWithColor:(uint)color;

/// Clears the texture with a certain color and alpha value. The previous contents of the
/// texture is wiped out.
- (void)clearWithColor:(uint)color alpha:(float)alpha;

/// ----------------
/// @name Properties
/// ----------------

/// Returns YES if image data has been uploaded to this texture, NO otherwise.
@property (nonatomic, readonly) BOOL dataUploaded;

@end
