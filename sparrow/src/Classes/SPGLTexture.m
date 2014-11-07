//
//  SPGLTexture.m
//  Sparrow
//
//  Created by Daniel Sperl on 27.06.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SparrowClass.h"
#import "SPContext_Internal.h"
#import "SPGLTexture.h"
#import "SPMacros.h"
#import "SPOpenGL.h"
#import "SPPVRData.h"
#import "SPRectangle.h"
#import "SPUtils.h"

@implementation SPGLTexture
{
    SPTextureFormat _format;
    SPTextureSmoothing _smoothing;
    uint _name;
    float _width;
    float _height;
    float _scale;
    BOOL _repeat;
    BOOL _premultipliedAlpha;
    BOOL _mipmaps;
    BOOL _dataUploaded;
    BOOL _isPowerOf2;
}

@synthesize name = _name;
@synthesize repeat = _repeat;
@synthesize premultipliedAlpha = _premultipliedAlpha;
@synthesize scale = _scale;
@synthesize format = _format;
@synthesize mipmaps = _mipmaps;
@synthesize smoothing = _smoothing;

#pragma mark Initialization

- (instancetype)initWithName:(uint)name format:(SPTextureFormat)format
                       width:(float)width height:(float)height containsMipmaps:(BOOL)mipmaps
                       scale:(float)scale premultipliedAlpha:(BOOL)pma;
{
    if ((self = [super init]))
    {
        if (width <= 0.0f)  [NSException raise:SPExceptionInvalidOperation format:@"invalid width"];
        if (height <= 0.0f) [NSException raise:SPExceptionInvalidOperation format:@"invalid height"];
        if (scale <= 0.0f)  [NSException raise:SPExceptionInvalidOperation format:@"invalid scale"];

        BOOL isPowerOf2 = [SPUtils isPowerOfTwo:width] && [SPUtils isPowerOfTwo:height];
        if (!isPowerOf2 && mipmaps)
            NSLog(@"Mipmaping enabled for non power of two texture. No mimaps will be created");
        
        _name = name;
        _width = width;
        _height = height;
        _isPowerOf2 = isPowerOf2;
        _mipmaps = mipmaps && isPowerOf2;
        _scale = scale;
        _format = format;
        _premultipliedAlpha = pma;
        _repeat = NO;
        _smoothing = SPTextureSmoothingBilinear;
    }

    return self;
}

- (instancetype)initWithData:(const void *)imgData properties:(SPTextureProperties)properties
{
    if (self = [self initWithName:0 format:properties.format width:properties.width height:properties.height
                  containsMipmaps:properties.generateMipmaps scale:properties.scale
               premultipliedAlpha:properties.premultipliedAlpha])
    {
        [self uploadData:imgData numMipmaps:properties.numMipmaps];
    }

    return self;
}

- (instancetype)initWithPVRData:(SPPVRData *)pvrData scale:(float)scale
{
    SPTextureProperties properties = {
        .format = pvrData.format,
        .scale  = scale,
        .width  = pvrData.width,
        .height = pvrData.height,
        .numMipmaps = pvrData.numMipmaps,
        .generateMipmaps = NO,
        .premultipliedAlpha = NO
    };

    return [self initWithData:pvrData.imageData properties:properties];
}

- (instancetype)init
{
    return [self initWithName:0 format:SPTextureFormatRGBA width:64 height:64 containsMipmaps:NO
                        scale:1.0f premultipliedAlpha:NO];
}

- (void)dealloc
{
    [[Sparrow context] destroyFramebufferForTexture:self];
    glDeleteTextures(1, &_name);
    [super dealloc];
}

#pragma mark Methods

- (void)uploadPVRData:(SPPVRData *)data
{
    [self uploadData:data.imageData numMipmaps:data.numMipmaps];
}

- (void)uploadData:(const void *)imgData
{
    [self uploadData:imgData numMipmaps:0];
}

- (void)uploadData:(const void *)imgData numMipmaps:(int)numMipmaps
{
    GLenum glTexType = GL_UNSIGNED_BYTE;
    GLenum glTexFormat;
    int bitsPerPixel;
    BOOL compressed = NO;

    switch (_format)
    {
        default:
        case SPTextureFormatRGBA:
            bitsPerPixel = 32;
            glTexFormat = GL_RGBA;
            break;
        case SPTextureFormatAlpha:
            bitsPerPixel = 8;
            glTexFormat = GL_ALPHA;
            break;
        case SPTextureFormatPvrtcRGBA2:
            compressed = YES;
            bitsPerPixel = 2;
            glTexFormat = GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG;
            break;
        case SPTextureFormatPvrtcRGB2:
            compressed = YES;
            bitsPerPixel = 2;
            glTexFormat = GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG;
            break;
        case SPTextureFormatPvrtcRGBA4:
            compressed = YES;
            bitsPerPixel = 4;
            glTexFormat = GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;
            break;
        case SPTextureFormatPvrtcRGB4:
            compressed = YES;
            bitsPerPixel = 4;
            glTexFormat = GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG;
            break;
        case SPTextureFormat565:
            bitsPerPixel = 16;
            glTexFormat = GL_RGB;
            glTexType = GL_UNSIGNED_SHORT_5_6_5;
            break;
        case SPTextureFormat888:
            bitsPerPixel = 24;
            glTexFormat = GL_RGB;
            break;
        case SPTextureFormat5551:
            bitsPerPixel = 16;
            glTexFormat = GL_RGBA;
            glTexType = GL_UNSIGNED_SHORT_5_5_5_1;
            break;
        case SPTextureFormat4444:
            bitsPerPixel = 16;
            glTexFormat = GL_RGBA;
            glTexType = GL_UNSIGNED_SHORT_4_4_4_4;
            break;
        case SPTextureFormatAI88:
            bitsPerPixel = 16;
            glTexFormat = GL_LUMINANCE_ALPHA;
            break;
        case SPTextureFormatI8:
            bitsPerPixel = 8;
            glTexFormat = GL_LUMINANCE;
    }

    if (!_name) glGenTextures(1, &_name);
    glBindTexture(GL_TEXTURE_2D, _name);

    if (!compressed)
    {
        int levelWidth  = _width;
        int levelHeight = _height;
        unsigned char *levelData = (unsigned char *)imgData;

        for (int level=0; level<=numMipmaps; ++level)
        {
            int size = levelWidth * levelHeight * bitsPerPixel / 8;
            glTexImage2D(GL_TEXTURE_2D, level, glTexFormat, levelWidth, levelHeight,
                         0, glTexFormat, glTexType, levelData);
            levelData += size;
            levelWidth  /= 2;
            levelHeight /= 2;
        }

        if (numMipmaps == 0 && _mipmaps)
            glGenerateMipmap(GL_TEXTURE_2D);
    }
    else
    {
        int levelWidth  = _width;
        int levelHeight = _height;
        unsigned char *levelData = (unsigned char *)imgData;

        for (int level=0; level<=numMipmaps; ++level)
        {
            int size = MAX(32, levelWidth * levelHeight * bitsPerPixel / 8);
            glCompressedTexImage2D(GL_TEXTURE_2D, level, glTexFormat,
                                   levelWidth, levelHeight, 0, size, levelData);
            levelData += size;
            levelWidth  /= 2;
            levelHeight /= 2;
        }
    }

    glBindTexture(GL_TEXTURE_2D, 0);

    self.repeat = _repeat;
    self.smoothing = _smoothing;

    _mipmaps = numMipmaps > 0 || (_mipmaps && !compressed);
    _dataUploaded = YES;
}

- (void)clear
{
    [self clearWithColor:0x0 alpha:0.0f];
}

- (void)clearWithColor:(uint)color
{
    [self clearWithColor:color alpha:1.0f];
}

- (void)clearWithColor:(uint)color alpha:(float)alpha
{
    SPContext *context = [Sparrow context];
    if (!context)
        [NSException raise:SPExceptionInvalidOperation format:@"Invalid context"];

    if (_premultipliedAlpha && alpha < 1.0)
        color = SP_COLOR(SP_COLOR_PART_RED(color)   * alpha,
                         SP_COLOR_PART_GREEN(color) * alpha,
                         SP_COLOR_PART_BLUE(color)  * alpha);

    SPTexture *previousRenderTarget = [context.renderTarget retain];
    
    [context setRenderTarget:self];
    [context clearWithColor:color alpha:alpha];

    context.renderTarget = previousRenderTarget;
    [previousRenderTarget release];
}

#pragma mark SPTexture

- (float)width
{
    return _width / _scale;
}

- (float)height
{
    return _height / _scale;
}

- (float)nativeWidth
{
    return _width;
}

- (float)nativeHeight
{
    return _height;
}

- (SPGLTexture *)root
{
    return self;
}

- (void)setRepeat:(BOOL)value
{
    if (!_isPowerOf2 && value)
    {
        value = NO;
        NSLog(@"Can't repeat textures that are non power of two.");
    }

    _repeat = value;
    glBindTexture(GL_TEXTURE_2D, _name);

    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _repeat ? GL_REPEAT : GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _repeat ? GL_REPEAT : GL_CLAMP_TO_EDGE);
}

- (void)setSmoothing:(SPTextureSmoothing)filterType
{
    _smoothing = filterType;
    glBindTexture(GL_TEXTURE_2D, _name);

    int magFilter, minFilter;

    if (_smoothing == SPTextureSmoothingNone)
    {
        magFilter = GL_NEAREST;
        minFilter = _mipmaps ? GL_NEAREST_MIPMAP_NEAREST : GL_NEAREST;
    }
    else if (_smoothing == SPTextureSmoothingBilinear)
    {
        magFilter = GL_LINEAR;
        minFilter = _mipmaps ? GL_LINEAR_MIPMAP_NEAREST : GL_LINEAR;
    }
    else
    {
        magFilter = GL_LINEAR;
        minFilter = _mipmaps ? GL_LINEAR_MIPMAP_LINEAR : GL_LINEAR;
    }

    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter);
}

@end
