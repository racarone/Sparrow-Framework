//
//  SPContext.m
//  Sparrow
//
//  Created by Robert Carone on 1/11/14.
//  Copyright 2011-2014 Gamua. All rights reserved.
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
#import <objc/runtime.h>

// --- EAGLContext category ------------------------------------------------------------------------

@interface EAGLContext (SPNSExtensions)

@property (nonatomic, assign) SPContext *spContext;

@end

@implementation EAGLContext (SPNSExtensions)

@dynamic spContext;

- (SPContext *)spContext
{
    return objc_getAssociatedObject(self, @selector(spContext));
}

- (void)setSpContext:(SPContext *)spContext
{
    objc_setAssociatedObject(self, @selector(spContext), spContext, OBJC_ASSOCIATION_ASSIGN);
}

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPContext
{
    EAGLContext *_nativeContext;
    SPTexture *_renderTarget;
    sglStateCacheRef _stateCache;

    NSMutableDictionary *_frameBufferCache;
    SPProgram *_program;
}

#pragma mark Initialization

- (instancetype)initWithShareContext:(SPContext *)shareContext
{
    if ((self = [super init]))
    {
        _nativeContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2
                                               sharegroup:shareContext.nativeContext.sharegroup];
        _nativeContext.spContext = self;

        _stateCache = sglStateCacheCreate();
        _frameBufferCache = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithShareContext:nil];
}

+ (instancetype)globalShareContext
{
    static SPContext *globalContext = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^
     {
         globalContext = [[SPContext alloc] init];
     });

    return globalContext;
}

- (void)dealloc
{
    [self makeCurrentContext];

    sglStateCacheDestroy(_stateCache);

    [_nativeContext release];
    [_renderTarget release];
    [_frameBufferCache release];
    [super dealloc];
}

#pragma mark Methods

- (void)renderToBackBuffer
{
    [self setRenderTarget:nil];
}

- (void)present
{
    [self makeCurrentContext];
    [_nativeContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)clear
{
    [self clearWithColor:0 alpha:1];
}

- (void)clearWithColor:(uint)color
{
    [self clearWithColor:color alpha:1];
}

- (void)clearWithColor:(uint)color alpha:(float)alpha
{
    float red   = SP_COLOR_PART_RED(color)   / 255.0f;
    float green = SP_COLOR_PART_GREEN(color) / 255.0f;
    float blue  = SP_COLOR_PART_BLUE(color)  / 255.0f;

    glClearColor(red, green, blue, alpha);
    glClear(GL_COLOR_BUFFER_BIT);
}

- (BOOL)makeCurrentContext
{
    return [[self class] setCurrentContext:self];
}

+ (BOOL)setCurrentContext:(SPContext *)context
{
    if ([EAGLContext setCurrentContext:context.nativeContext])
    {
        sglStateCacheSetCurrent(context->_stateCache);
        return YES;
    }

    return NO;
}

+ (SPContext *)currentContext
{
    return [EAGLContext currentContext].spContext;
}

+ (BOOL)deviceSupportsOpenGLExtension:(NSString *)extensionName
{
    static dispatch_once_t once;
    static NSArray *extensions = nil;

    dispatch_once(&once, ^
     {
         NSString *extensionsString = [NSString stringWithCString:(const char *)glGetString(GL_EXTENSIONS)
                                       encoding:NSASCIIStringEncoding];

         extensions = [[extensionsString componentsSeparatedByString:@" "] retain];
     });

    return [extensions containsObject:extensionName];
}

#pragma mark Properties

- (SPRectangle *)viewport
{
    struct { int x, y, w, h; } viewport;
    glGetIntegerv(GL_VIEWPORT, (int *)&viewport);
    return [SPRectangle rectangleWithX:viewport.x y:viewport.y width:viewport.w height:viewport.h];
}

- (void)setViewport:(SPRectangle *)viewport
{
    if (viewport) glViewport(viewport.x, viewport.y, viewport.width, viewport.height);
    else          glViewport(0, 0, (int)[[[Sparrow currentController] view] drawableWidth], (int)[[[Sparrow currentController] view] drawableHeight]);
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
        uint framebuffer = [_frameBufferCache[@(renderTarget.name)] unsignedIntValue];
        if (!framebuffer)
        {
            // create and cache the framebuffer
            framebuffer = [self createFramebufferForTexture:renderTarget];
            _frameBufferCache[@(renderTarget.name)] = @(framebuffer);
        }

        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glViewport(0, 0, renderTarget.nativeWidth, renderTarget.nativeHeight);
    }
    else
    {
        [[[Sparrow currentController] view] bindDrawable];
    }

  #if DEBUG
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        NSLog(@"Currently bound framebuffer is invalid");
  #endif

    SP_RELEASE_AND_RETAIN(_renderTarget, renderTarget);
}

@end

// -------------------------------------------------------------------------------------------------

@implementation SPContext (Internal)

- (uint)createFramebufferForTexture:(SPTexture *)texture
{
    uint framebuffer = -1;

    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture.name, 0);

    return framebuffer;
}

- (void)destroyFramebufferForTexture:(SPTexture *)texture
{
    uint framebuffer = [_frameBufferCache[@(texture.name)] unsignedIntValue];
    if (framebuffer)
    {
        glDeleteFramebuffers(1, &framebuffer);
        [_frameBufferCache removeObjectForKey:@(texture.name)];
    }
}

@end
