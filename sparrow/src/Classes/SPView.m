//
//  SPView.m
//  Sparrow
//
//  Created by Robert Carone on 2/8/14.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass_Internal.h>
#import <Sparrow/SPContext.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPView.h>
#import <Sparrow/SPViewController.h>

@implementation SPView
{
    SPContext *_context;
    SPViewController *__weak _viewController;
    int _antiAliasing;
    BOOL _enableDepthAndStencil;
    BOOL _supportHighResolutions;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.opaque = YES;
    self.clearsContextBeforeDrawing = NO;
    self.multipleTouchEnabled = YES;
}

#pragma mark Methods

- (void)configureBackBuffer
{
    [_context makeCurrentContext];
    [_context configureBackBufferForView:self antiAlias:_antiAliasing
	 enableDepthAndStencil:_enableDepthAndStencil wantsBestResolution:_supportHighResolutions];
}

#pragma mark View

- (void)displayLayer:(CALayer *)layer
{
    [self configureBackBuffer];
    [_viewController nextFrame];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [_viewController nextFrame];
}

#pragma mark Propertiess

- (void)setContext:(SPContext *)context
{
    if (context != _context)
    {
        SP_RELEASE_AND_RETAIN(_context, context);

        [_context makeCurrentContext];
        [self prepareOpenGLState];
        [self configureBackBuffer];
    }
}

- (void)setEnableDepthAndStencil:(BOOL)enableDepthAndStencil
{
    if (enableDepthAndStencil != _enableDepthAndStencil)
    {
        _enableDepthAndStencil = enableDepthAndStencil;
        [self configureBackBuffer];
    }
}

- (void)setAntiAliasing:(int)antiAliasing
{
    if (antiAliasing != _antiAliasing)
    {
        _antiAliasing = antiAliasing;
        [self configureBackBuffer];
    }
}

- (void)setSupportHighResolutions:(BOOL)supportHighResolutions
{
    if (supportHighResolutions != _supportHighResolutions)
    {
        _supportHighResolutions = supportHighResolutions;
        [self configureBackBuffer];
    }
}

- (void)prepareOpenGLState
{
    glDisable(GL_CULL_FACE);
    glDisable(GL_DITHER);
    glDisable(GL_STENCIL_TEST);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glDepthFunc(GL_ALWAYS);
    glBlendColor(0.0, 0.0, 0.0, 1.0);
    glLineWidth(1.0);
}

@end
