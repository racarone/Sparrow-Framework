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
#import <Sparrow/SPGLTexture.h>
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

    int _backBufferWidth;
    int _backBufferHeight;
    uint _colorRenderBuffer;
    uint _depthStencilRenderBuffer;
    uint _frameBuffer;
    uint _msaaFrameBuffer;
    uint _msaaColorRenderBuffer;
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

    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    if (_frameBuffer)
    {
        glDeleteFramebuffers(1, &_frameBuffer);
        _frameBuffer = 0;
    }

    if (_colorRenderBuffer)
    {
        glDeleteRenderbuffers(1, &_colorRenderBuffer);
        _colorRenderBuffer = 0;
    }

    if (_depthStencilRenderBuffer)
    {
        glDeleteRenderbuffers(1, &_depthStencilRenderBuffer);
        _depthStencilRenderBuffer = 0;
    }

    if (_msaaFrameBuffer)
    {
        glDeleteFramebuffers(1, &_msaaFrameBuffer);
        _msaaFrameBuffer = 0;
    }

    if (_msaaColorRenderBuffer)
    {
        glDeleteRenderbuffers(1, &_msaaColorRenderBuffer);
        _msaaColorRenderBuffer = 0;
    }

    sglStateCacheDestroy(_stateCache);

    [_nativeContext release];
    [_renderTarget release];
    [_frameBufferCache release];
    [super dealloc];
}

#pragma mark Methods

- (void)configureBackBufferForView:(SPView *)view antiAlias:(int)antiAlias
             enableDepthAndStencil:(BOOL)enableDepthAndStencil
               wantsBestResolution:(BOOL)wantsBestResolution
{
    [self makeCurrentContext];

    view.layer.contentsScale = wantsBestResolution ? view.window.screen.scale : 1.0f;

    if (!_frameBuffer)
    {
        glGenFramebuffers(1, &_frameBuffer);
        glGenRenderbuffers(1, &_colorRenderBuffer);

        glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);

    [_nativeContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)view.layer];

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backBufferWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backBufferHeight);

    if (antiAlias && !_msaaFrameBuffer)
    {
        glGenFramebuffers(1, &_msaaFrameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _msaaFrameBuffer);

        glGenRenderbuffers(1, &_msaaColorRenderBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _msaaColorRenderBuffer);

        glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, antiAlias, GL_RGBA8_OES, _backBufferWidth, _backBufferHeight);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _msaaColorRenderBuffer);
    }
    else if (!antiAlias && _msaaFrameBuffer)
    {
        glDeleteFramebuffers(1, &_msaaFrameBuffer);
        _msaaFrameBuffer = 0;

        glDeleteRenderbuffers(1, &_msaaColorRenderBuffer);
        _msaaColorRenderBuffer = 0;
    }

    if (enableDepthAndStencil && !_depthStencilRenderBuffer)
    {
        glGenRenderbuffers(1, &_depthStencilRenderBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _depthStencilRenderBuffer);

        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthStencilRenderBuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _depthStencilRenderBuffer);

        if (_msaaFrameBuffer)
            glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, antiAlias, GL_DEPTH24_STENCIL8, _backBufferWidth, _backBufferHeight);
        else
            glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, _backBufferWidth, _backBufferHeight);
    }
    else if (!enableDepthAndStencil && _depthStencilRenderBuffer)
    {
        glDeleteRenderbuffers(1, &_depthStencilRenderBuffer);
        _depthStencilRenderBuffer = 0;
    }
}

- (void)renderToBackBuffer
{
    [self setRenderTarget:nil];
}

- (void)present
{
    [self makeCurrentContext];

    if (_msaaFrameBuffer)
    {
        if (_depthStencilRenderBuffer)
        {
            GLenum attachments[] = { GL_COLOR_ATTACHMENT0, GL_STENCIL_ATTACHMENT, GL_DEPTH_ATTACHMENT };
            glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 3, attachments);
        }
        else
        {
            GLenum attachments[] = { GL_COLOR_ATTACHMENT0 };
            glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 1, attachments);
        }
    }
    else if (_depthStencilRenderBuffer)
    {
        GLenum attachments[] = { GL_STENCIL_ATTACHMENT, GL_DEPTH_ATTACHMENT };
        glDiscardFramebufferEXT(GL_FRAMEBUFFER, 2, attachments);
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
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
    else          glViewport(0, 0, _backBufferWidth, _backBufferHeight);
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
        glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
        glViewport(0, 0, _backBufferWidth, _backBufferHeight);
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
    if (!texture.root.dataUploaded)
        [texture.root uploadData:NULL];

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
