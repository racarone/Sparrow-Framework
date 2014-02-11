//
//  SPDisplayLink.m
//  Sparrow
//
//  Created by Robert Carone on 2/5/14.
//  Copyright 2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPDisplayLink.h>

#import <QuartzCore/QuartzCore.h>
#if !TARGET_OS_IPHONE
    #import <CoreVideo/CoreVideo.h>
#endif

#import <libkern/OSAtomic.h>

#pragma mark - SPDisplayLink

@interface SPDisplayLink ()

- (void)setup;
- (void)teardown;
- (void)start;
- (void)restart;
- (void)nsTimerCallback;
- (void)callbackForNextFrame:(double)passedTime;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPDisplayLink
{
  #if TARGET_OS_IPHONE
    CADisplayLink *_caDisplayLink;
  #else
    CVDisplayLinkRef _cvDisplayLink;
  #endif

    NSTimer *_timer;
    SPDisplayLinkMode _mode;
    SPDisplayLinkBlock _block;
    dispatch_queue_t _queue;
    BOOL _paused;
    BOOL _asynchronous;
    double _frameCountBeginTime;
    double _previousFrameTime;
    float _averageFrameTime;
    int _queuedFrameCount;
    int _maxQueuedFrameCount;
    int _frameInterval;
    int _frameCount;
}

#pragma mark Initialization

- (instancetype)initWithQueue:(dispatch_queue_t)queue block:(SPDisplayLinkBlock)block
{
    if ((self = [super init]))
    {
        _maxQueuedFrameCount = 3;
        _frameInterval = 1;
        _paused = YES;
        _mode = SPDisplayLinkModeLink;
        _block = [block copy];
        _queue = (dispatch_queue_t)[(id)queue retain];
    }
    return self;
}

- (instancetype)initWithBlock:(SPDisplayLinkBlock)block
{
    return [self initWithQueue:nil block:block];
}

- (instancetype)init
{
    [self release];
    return nil;
}

- (void)dealloc
{
    [self teardown];

    [_block release];
    [(id)_queue release];
    [super dealloc];
}

+ (instancetype)displayLinkWithQueue:(dispatch_queue_t)queue block:(SPDisplayLinkBlock)block;
{
    return [[[self alloc] initWithQueue:queue block:block] autorelease];
}

+ (instancetype)displayLinkWithBlock:(SPDisplayLinkBlock)block
{
    return [[[self alloc] initWithBlock:block] autorelease];
}

#pragma mark Properties

- (void)setPaused:(BOOL)paused
{
    if (paused != _paused)
    {
        _paused = paused;

        if (_paused)
            [self teardown];
        else
        {
            [self setup];
            [self start];
        }
    }
}

- (void)setMode:(SPDisplayLinkMode)mode
{
    _mode = mode;

    [self teardown];
    [self setup];

    if (!_paused)
        [self start];
}

- (void)setFrameInterval:(int)frameInterval
{
    if (frameInterval != _frameInterval)
    {
        _frameInterval = frameInterval;
  #if TARGET_OS_IPHONE
        if (_mode == SPDisplayLinkModeLink)
        {
            _caDisplayLink.frameInterval = _frameInterval;
            [self restart];
        }
  #endif
    }
}

#pragma mark Private

- (void)setup
{
  #if TARGET_OS_IPHONE
    if (_mode == SPDisplayLinkModeLink)
    {
        if (_caDisplayLink)
        {
            [_caDisplayLink invalidate];
            [_caDisplayLink release];
            _caDisplayLink = nil;
        }

        _caDisplayLink = [[CADisplayLink displayLinkWithTarget:self selector:@selector(caDisplayLinkCallback)] retain];
        _caDisplayLink.frameInterval = _frameInterval;
    }
  #else
    if (_mode == SPDisplayLinkModeLink)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_cvDisplayLink)
            {
                CVDisplayLinkStop(_cvDisplayLink);
                CVDisplayLinkRelease(_cvDisplayLink);
                _cvDisplayLink = NULL;
            }

            CVDisplayLinkCreateWithActiveCGDisplays(&_cvDisplayLink);
            CVDisplayLinkSetOutputCallback(_cvDisplayLink, (CVDisplayLinkOutputCallback)cvDisplayLinkOutputCallback, self);
        });
    }
  #endif
}

- (void)teardown
{
    if (_mode == SPDisplayLinkModeLink)
    {
  #if TARGET_OS_IPHONE
        [_caDisplayLink invalidate];
        [_caDisplayLink release];
        _caDisplayLink = nil;
  #else
        if (_cvDisplayLink)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                CVDisplayLinkStop(_cvDisplayLink);
                CVDisplayLinkRelease(_cvDisplayLink);
                _cvDisplayLink = NULL;
            });
        }
  #endif
    }
    else if (_mode == SPDisplayLinkModeTimer)
    {
        [_timer invalidate];
        [_timer release];
        _timer = nil;
    }
}

- (void)start
{
    _averageFrameTime = 0;
    _frameCountBeginTime = 0;
    _frameCount = 0;

    if (_mode == SPDisplayLinkModeLink)
    {
  #if TARGET_OS_IPHONE
        if (_caDisplayLink)
        {
            if (_queue == dispatch_get_main_queue())
            {
                [(id)_queue release];
                _queue = nil;
            }

            [_caDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }
  #else
        dispatch_async(dispatch_get_main_queue(), ^{
            CVDisplayLinkStart(_cvDisplayLink);
        });
  #endif
    }
    else if (_mode == SPDisplayLinkModeTimer)
    {
        _timer = [[NSTimer scheduledTimerWithTimeInterval:_frameInterval / 60.0 target:self
               	           selector:@selector(nsTimerCallback) userInfo:nil repeats:YES] retain];
    }
}

- (void)restart
{
    [self setup];
    [self start];
}

#pragma mark Callbacks

#if !TARGET_OS_IPHONE
static CVReturn cvDisplayLinkOutputCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime,
                                            CVOptionFlags flagsIn, CVOptionFlags *flagsOut, SPDisplayLink *spDisplayLink)
{
    [spDisplayLink retain];

    double currentTime = CACurrentMediaTime();
    if (inNow->videoTimeScale == 0 || inOutputTime->videoTimeScale == 0)
    {
        double frameTime = currentTime + (spDisplayLink.frameInterval / 60.0);
        [spDisplayLink callbackForNextFrame:frameTime];
    }
    else
    {
        double nowTime    = (double)inNow->videoTime / (double)inNow->videoTimeScale;
        double outputTime = (double)inOutputTime->videoTime / (double)inOutputTime->videoTimeScale;
        double frameTime  = currentTime + (outputTime - nowTime);
        [spDisplayLink callbackForNextFrame:frameTime];
    }

    [spDisplayLink release];
    return kCVReturnSuccess;
}
#endif

#if TARGET_OS_IPHONE
- (void)caDisplayLinkCallback
{
    double frameTime = _caDisplayLink.timestamp + (_caDisplayLink.duration * (double)_frameInterval);
    [self callbackForNextFrame:frameTime];
}
#endif

- (void)nsTimerCallback
{
    double currentTime = CACurrentMediaTime();
    double intervalTime = _frameInterval / 62.0;
    double frameTime = _previousFrameTime + intervalTime;

    if ((frameTime < currentTime) || (currentTime + intervalTime < frameTime))
        frameTime = currentTime + (intervalTime * 0.5);

    [self callbackForNextFrame:frameTime];
}

- (void)callbackForNextFrame:(double)frameTime
{
    if (!_paused)
    {
        if (OSAtomicAdd32(1, &_queuedFrameCount) <= _maxQueuedFrameCount || !_maxQueuedFrameCount)
        {
            if (_queue)
            {
                if (_asynchronous)
                {
                    dispatch_async(_queue, ^{
                        _block(frameTime);
                        OSAtomicAdd32(-1, &_queuedFrameCount);
                    });
                }
                else
                {
                    dispatch_sync(_queue, ^{
                        _block(frameTime);
                        OSAtomicAdd32(-1, &_queuedFrameCount);
                    });
                }
            }
            else
            {
                _block(frameTime);
                OSAtomicAdd32(-1, &_queuedFrameCount);
            }
        }
        else
        {
            OSAtomicAdd32(-1, &_queuedFrameCount);
        }

        _frameCount += 1;
        if (_frameCount >= 5)
        {
            _averageFrameTime = (frameTime - _frameCountBeginTime) / _frameCount;
            _frameCountBeginTime = frameTime;
            _frameCount = 0;
        }

        float interval = _frameInterval / 60.0f;
        float delta = frameTime - _previousFrameTime;
        if ((interval * 0.75f) > delta && fabsf(delta - _averageFrameTime) < 0.002f)
            [self restart];
        
        _previousFrameTime = frameTime;
    }
}

@end
