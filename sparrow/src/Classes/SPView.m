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

#import "SPContext.h"
#import "SPDisplayLink.h"
#import "SPOpenGL.h"
#import "SPView.h"

#pragma mark - SPView

@interface SPView ()
@property (nonatomic, readonly) CAEAGLLayer *glLayer;
@end

@implementation SPView
{
    SPContext *_context;
    dispatch_queue_t _renderQueue;
    float _prevViewScaleFactor;
    int _drawableWidth;
    int _drawableHeight;
    uint _colorRenderBuffer;
    uint _depthStencilRenderBuffer;
    uint _frameBuffer;
    BOOL _shouldDeleteFramebuffer;
    BOOL _rendering;
    BOOL _paused;
}

#pragma mark Initialization

- (instancetype)initWithFrame:(CGRect)frame context:(SPContext *)context
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setup];
        [self setContext:context];
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame context:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
        [self setup];

    return self;
}

- (void)setup
{
    _enableSetNeedsDisplay = YES;
    _renderQueue = dispatch_queue_create("Sparrow-RenderQueue", NULL);

    [self setUserInteractionEnabled:YES];
    [self setMultipleTouchEnabled:YES];
    [self setContentScaleFactor:0];
}

- (void)dealloc
{
    dispatch_sync(_renderQueue, ^{
        [self deleteFramebuffer];
    });

    [(id)_renderQueue release];
    [_context release];
    [super dealloc];
}

#pragma mark Methods

- (void)render
{
    __block id weakSelf = self;
    dispatch_sync(_renderQueue, ^{
        [weakSelf displayAndPresentRenderbuffer:YES];
    });
}

- (void)bindDrawable
{
    if (_rendering)
         [self setFramebuffer:NULL];
    else
        dispatch_sync(_renderQueue, ^{ [self setFramebuffer:NULL]; });
}

- (void)deleteDrawable
{
    if (_rendering)
        [self deleteFramebuffer];
    else
        dispatch_sync(_renderQueue, ^{ [self deleteFramebuffer]; });
}

#pragma mark View

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)displayLayer:(CALayer *)layer
{
    if (_enableSetNeedsDisplay)
        [self displayAndPresentRenderbuffer:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _shouldDeleteFramebuffer = YES;
}

#pragma mark Properties

- (void)setContext:(SPContext *)context
{
    if (context != _context)
    {
        SP_RELEASE_AND_RETAIN(_context, context);
        [self bindOpenGLContext];
    }
}

- (CAEAGLLayer *)glLayer
{
    return (CAEAGLLayer *)self.layer;
}

#pragma mark OpenGL

- (BOOL)bindOpenGLContext
{
    if (_context) return [SPContext setCurrentContext:_context];
    else          return NO;
}

- (void)deleteFramebuffer
{
    if (_context && [self bindOpenGLContext])
    {
        glPushGroupMarkerEXT(0, "Delete Framebuffer");
        _shouldDeleteFramebuffer = NO;

        if (_frameBuffer)
        {
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            glDeleteFramebuffers(1, &_frameBuffer);
            _frameBuffer = 0;
        }

        if (_colorRenderBuffer || _depthStencilRenderBuffer)
        {
            glBindRenderbuffer(GL_RENDERBUFFER, 0);

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
        }

        glPopGroupMarkerEXT();
    }
}

- (void)remakeFrameBufferWithScaleFactor:(float)scaleFactor
{
    if (_context && [self bindOpenGLContext])
    {
        self.glLayer.opaque = YES;
        self.glLayer.contentsScale = scaleFactor;

        glPushGroupMarkerEXT(0, "Create Framebuffer");

        if (_frameBuffer)
            glDeleteBuffers(1, &_frameBuffer);

        if (_colorRenderBuffer)
            glDeleteBuffers(1, &_colorRenderBuffer);

        if (_depthStencilRenderBuffer)
            glDeleteBuffers(1, &_depthStencilRenderBuffer);

        glGenBuffers(1, &_frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);

        glGenBuffers(1, &_colorRenderBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);

        [_context.nativeContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.glLayer];
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);

        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_drawableWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_drawableHeight);

        glGenRenderbuffers(1, &_depthStencilRenderBuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, _drawableWidth, _drawableHeight);

        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthStencilRenderBuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _depthStencilRenderBuffer);

        glPopGroupMarkerEXT();

        GLenum error = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (error != GL_FRAMEBUFFER_COMPLETE)
        {
            NSLog(@"Failed to make complete framebuffer object %s", sglGetErrorString(error));
            [self deleteFramebuffer];
        }

        _prevViewScaleFactor = scaleFactor;
    }
}

- (void)displayAndPresentRenderbuffer:(BOOL)presentRenderbuffer
{
    _rendering = YES;

    if (!_context)
        [self setupContext];

    if (_context && [self bindOpenGLContext])
    {
        glPushGroupMarkerEXT(0, "Rendering");

        BOOL needsFinish = NO;
        [self setFramebuffer:&needsFinish];

        glDisable(GL_CULL_FACE);
        glDisable(GL_DITHER);
        glDisable(GL_STENCIL_TEST);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glDepthFunc(GL_ALWAYS);
        glBlendColor(0, 0, 0, 1.0);
        glLineWidth(1.0);

        if (_delegate && [_delegate respondsToSelector:@selector(renderRect:view:)])
            [_delegate renderRect:self.bounds view:self];
        else
            [self drawRect:self.bounds];

        static const GLenum attachements[] = { GL_COLOR_ATTACHMENT0, GL_DEPTH_ATTACHMENT };
        glDiscardFramebufferEXT(GL_FRAMEBUFFER, 2, attachements);

        if (presentRenderbuffer)
        {
            glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
            [_context.nativeContext presentRenderbuffer:GL_RENDERBUFFER];
        }

        glPopGroupMarkerEXT();

        if (needsFinish)
            glFinish();
    }

    _rendering = NO;
}

- (void)setFramebuffer:(BOOL *)needsFinish
{
    if (needsFinish) *needsFinish = NO;
    if (_context && [self bindOpenGLContext])
    {
        if (_shouldDeleteFramebuffer)
            [self deleteFramebuffer];

        float scaleFactor;
        if (self.window.screen) scaleFactor = self.window.screen.scale;
        else                    scaleFactor = UIScreen.mainScreen.scale;

        if (!_frameBuffer || scaleFactor != _prevViewScaleFactor)
        {
            [self remakeFrameBufferWithScaleFactor:scaleFactor];
            if (needsFinish) *needsFinish = YES;
        }

        glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
        glViewport(0, 0, _drawableWidth, _drawableHeight);
    }
}

- (void)setupContext
{
    self.context = [[SPContext alloc] init];
    if (_context)
    {
        [self setOpaque:YES];
        [self setClearsContextBeforeDrawing:NO];
    }
}

@end
