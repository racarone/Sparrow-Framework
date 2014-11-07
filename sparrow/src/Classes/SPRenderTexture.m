//
//  SPRenderTexture.m
//  Sparrow
//
//  Created by Daniel Sperl on 04.12.10.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPGLTexture.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPRenderSupport.h>
#import <Sparrow/SPRenderTexture.h>
#import <Sparrow/SPStage.h>
#import <Sparrow/SPUtils.h>

@implementation SPRenderTexture
{
    BOOL _framebufferIsActive;
    SPRenderSupport *_renderSupport;
}

#pragma mark Initialization

- (instancetype)initWithWidth:(float)width height:(float)height fillColor:(uint)argb scale:(float)scale
{
    int legalWidth  = [SPUtils nextPowerOfTwo:width  * scale];
    int legalHeight = [SPUtils nextPowerOfTwo:height * scale];
    
    SPTextureProperties properties = {
        .format = SPTextureFormatRGBA,
        .scale  = scale,
        .width  = legalWidth,
        .height = legalHeight,
        .numMipmaps = 0,
        .generateMipmaps = NO,
        .premultipliedAlpha = YES
    };
    
    SPRectangle *region = [SPRectangle rectangleWithX:0 y:0 width:width height:height];
    SPGLTexture *glTexture = [[SPGLTexture alloc] initWithData:NULL properties:properties];

    if ((self = [super initWithRegion:region ofTexture:glTexture]))
    {
        _renderSupport = [[SPRenderSupport alloc] init];
        [self clearWithColor:argb alpha:SPColorGetAlpha(argb)];
    }

    [glTexture release];
    return self;
}

- (instancetype)initWithWidth:(float)width height:(float)height fillColor:(uint)argb
{
    return [self initWithWidth:width height:height fillColor:argb scale:Sparrow.contentScaleFactor];
}

- (instancetype)initWithWidth:(float)width height:(float)height
{
    return [self initWithWidth:width height:height fillColor:0x0];
}

- (instancetype)init
{
    return [self initWithWidth:256 height:256];    
}

- (void)dealloc
{
    [_renderSupport release];
    [super dealloc];
}

+ (instancetype)textureWithWidth:(float)width height:(float)height
{
    return [[[self alloc] initWithWidth:width height:height] autorelease];
}

+ (instancetype)textureWithWidth:(float)width height:(float)height fillColor:(uint)argb
{
    return [[[self alloc] initWithWidth:width height:height fillColor:argb] autorelease];
}

#pragma mark Methods

- (void)drawObject:(SPDisplayObject *)object withMatrix:(SPMatrix *)matrix alpha:(float)alpha
         blendMode:(uint)blendMode
{
    [self renderToFramebuffer:^
     {
         [_renderSupport pushStateWithMatrix:matrix alpha:alpha blendMode:blendMode];
         [object render:_renderSupport];
         [_renderSupport popState];
     }];
}

- (void)drawObject:(SPDisplayObject *)object withMatrix:(SPMatrix *)matrix alpha:(float)alpha
{
    [self drawObject:object withMatrix:matrix alpha:alpha blendMode:object.blendMode];
}

- (void)drawObject:(SPDisplayObject *)object withMatrix:(SPMatrix *)matrix
{
    [self drawObject:object withMatrix:matrix alpha:object.alpha blendMode:object.blendMode];
}

- (void)drawObject:(SPDisplayObject *)object
{
    [self drawObject:object withMatrix:object.transformationMatrix
               alpha:object.alpha blendMode:object.blendMode];
}

- (void)drawBundled:(SPDrawingBlock)block
{
    [self renderToFramebuffer:block];
}

- (void)clearWithColor:(uint)color alpha:(float)alpha
{
    [self renderToFramebuffer:^
     {
         [SPRenderSupport clearWithColor:color alpha:alpha];
     }];
}

- (void)clear
{
    [self clearWithColor:0x0 alpha:0.0];
}

#pragma mark Private

- (void)renderToFramebuffer:(SPDrawingBlock)block
{
    if (!block) return;

    // the block may call a draw-method again, so we're making sure that the frame buffer switching
    // happens only in the outermost block.

    BOOL isDrawing = _framebufferIsActive;
    SPTexture *previousTarget = nil;

    if (!isDrawing)
    {
        _framebufferIsActive = YES;

        // remember standard frame buffer
        previousTarget = [_renderSupport.renderTarget retain];

        SPGLTexture *rootTexture = self.root;
        float width  = rootTexture.width;
        float height = rootTexture.height;

        // switch to the texture's framebuffer for rendering
        _renderSupport.renderTarget = rootTexture;

        // prepare clipping and OpenGL matrices
        [_renderSupport pushClipRect:[SPRectangle rectangleWithX:0 y:0 width:width height:height]];
        [_renderSupport setupOrthographicProjectionWithLeft:0 right:width top:height bottom:0];
    }

    block();

    if (!isDrawing)
    {
        _framebufferIsActive = NO;

        [_renderSupport finishQuadBatch];
        [_renderSupport nextFrame];

        // return to standard frame buffer
        _renderSupport.renderTarget = previousTarget;
        [previousTarget release];
    }
}

@end
