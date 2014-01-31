//
//  SPContext.m
//  Sparrow
//
//  Created by Robert Carone on 1/11/14.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPContext_Internal.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPTexture.h>

#import <GLKit/GLKit.h>
#import <OpenGLES/EAGL.h>

#define currentThreadDictionary [[NSThread currentThread] threadDictionary]
static NSString *const currentContextKey = @"SPCurrentContext";
static NSMutableDictionary *framebufferCache = nil;

// --- class implementation ------------------------------------------------------------------------

@implementation SPContext
{
    EAGLContext *_nativeContext;
    SPTexture *_renderTarget;
}

#pragma mark Initialization

- (instancetype)initWithSharegroup:(id)sharegroup
{
    if ((self = [super init]))
    {
        _nativeContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2
                                               sharegroup:sharegroup];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithSharegroup:nil];
}

- (void)dealloc
{
    [_nativeContext release];
    [_renderTarget release];

    [super dealloc];
}

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        framebufferCache = [[NSMutableDictionary alloc] init];
    });
}

#pragma mark Methods

- (void)renderToBackBuffer
{
    [self setRenderTarget:nil];
}

- (void)presentBufferForDisplay
{
    [_nativeContext presentRenderbuffer:GL_RENDERBUFFER];
}

+ (BOOL)setCurrentContext:(SPContext *)context
{
    if (context && [EAGLContext setCurrentContext:context->_nativeContext])
    {
        currentThreadDictionary[currentContextKey] = context;
        return YES;
    }

    return NO;
}

+ (SPContext *)currentContext
{
    SPContext *current = currentThreadDictionary[currentContextKey];
    if (!current || current->_nativeContext != [EAGLContext currentContext])
        return nil;

    return current;
}

+ (BOOL)deviceSupportsOpenGLExtension:(NSString *)extensionName
{
    static dispatch_once_t once;
    static NSArray *extensions = nil;

    dispatch_once(&once, ^{
        NSString *extensionsString = [NSString stringWithCString:(const char *)glGetString(GL_EXTENSIONS) encoding:NSASCIIStringEncoding];
        extensions = [[extensionsString componentsSeparatedByString:@" "] retain];
    });

    return [extensions containsObject:extensionName];
}

#pragma mark Properties

- (id)sharegroup
{
    return _nativeContext.sharegroup;
}

- (id)nativeContext
{
    return _nativeContext;
}

- (SPRectangle *)viewport
{
    struct { int x, y, w, h; } viewport;
    glGetIntegerv(GL_VIEWPORT, (int *)&viewport);
    return [SPRectangle rectangleWithX:viewport.x y:viewport.y width:viewport.w height:viewport.h];
}

- (void)setViewport:(SPRectangle *)viewport
{
    if (viewport)
        glViewport(viewport.x, viewport.y, viewport.width, viewport.height);
    else
        glViewport(0, 0, Sparrow.currentController.drawableWidth, Sparrow.currentController.drawableHeight);
}

- (SPRectangle *)scissorBox
{
    struct { int x, y, w, h; } scissorBox;
    glGetIntegerv(GL_SCISSOR_BOX, (int *)&scissorBox);
    return [SPRectangle rectangleWithX:scissorBox.x y:scissorBox.y width:scissorBox.w height:scissorBox.h];
}

- (void)setScissorBox:(SPRectangle *)scissorBox
{
    if (scissorBox)
    {
        glEnable(GL_SCISSOR_TEST);
        glScissor(scissorBox.x, scissorBox.y, scissorBox.width, scissorBox.height);
    }
    else
    {
        glDisable(GL_SCISSOR_TEST);
    }
}

- (void)setRenderTarget:(SPTexture *)renderTarget
{
    if (renderTarget)
    {
        uint framebuffer = [framebufferCache[@(renderTarget.name)] unsignedIntValue];
        if (!framebuffer)
        {
            // create and cache the framebuffer
            framebuffer = [self createFramebufferForTexture:renderTarget];
            framebufferCache[@(renderTarget.name)] = @(framebuffer);
        }

        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glViewport(0, 0, renderTarget.nativeWidth, renderTarget.nativeHeight);
    }
    else
    {
        glBindFramebuffer(GL_FRAMEBUFFER, 1);
        glViewport(0, 0, Sparrow.currentController.drawableWidth, Sparrow.currentController.drawableHeight);
    }

    SP_RELEASE_AND_RETAIN(_renderTarget, renderTarget);
}

@end

// -------------------------------------------------------------------------------------------------

@implementation SPContext (Internal)

- (uint)createFramebufferForTexture:(SPTexture *)texture
{
    uint framebuffer = -1;

    // create framebuffer
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);

    // attach renderbuffer
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture.name, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        NSLog(@"failed to create frame buffer for render texture");

    return framebuffer;
}

- (void)destroyFramebufferForTexture:(SPTexture *)texture
{
    uint framebuffer = [framebufferCache[@(texture.name)] unsignedIntValue];
    if (framebuffer)
    {
        glDeleteFramebuffers(1, &framebuffer);
        [framebufferCache removeObjectForKey:@(texture.name)];
    }
}

@end
