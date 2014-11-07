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
#if SP_TARGET_OSX
    #import <CoreVideo/CoreVideo.h>
#endif

#import <libkern/OSAtomic.h>

// --- class extension -----------------------------------------------------------------------------

@interface SPDisplayLink ()

@property (nonatomic, assign) double timestamp;
@property (nonatomic, assign) double duration;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPDisplayLink
{
  #if SP_TARGET_IOS
    CADisplayLink *_caDisplayLink;
  #else
    CVDisplayLinkRef _cvDisplayLink;
  #endif

    SPCallbackBlock _block;
    dispatch_queue_t _queue;
    BOOL _paused;
    BOOL _asynchronous;
    double _timestamp;
    double _duration;
    double _frameCountBeginTime;
    float _averageFrameTime;
    int _queuedFrameCount;
    int _maxQueuedFrameCount;
    int _frameInterval;
    int _frameCount;
}

#pragma mark Initialization

- (instancetype)initWithQueue:(dispatch_queue_t)queue block:(SPCallbackBlock)block
{
    if ((self = [super init]))
    {
        _maxQueuedFrameCount = 3;
        _frameInterval = 1;
        _paused = YES;
        _block = [block copy];
        _queue = (dispatch_queue_t)[(id)queue retain];
    }
    return self;
}

- (instancetype)initWithBlock:(SPCallbackBlock)block
{
    return [self initWithQueue:dispatch_get_main_queue() block:block];
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

- (void)setFrameInterval:(int)frameInterval
{
    if (frameInterval != _frameInterval)
    {
        _frameInterval = frameInterval;

        SP_EXECUTE_ON_IOS
        ({
            _caDisplayLink.frameInterval = _frameInterval;
            [self restart];
        });
    }
}

#pragma mark Private

- (void)setup
{
    SP_EXECUTE_ON_IOS
    ({
        if (_caDisplayLink)
        {
            [_caDisplayLink invalidate];
            [_caDisplayLink release];
            _caDisplayLink = nil;
        }

        _caDisplayLink = [[CADisplayLink displayLinkWithTarget:self selector:@selector(caDisplayLinkCallback)] retain];
        _caDisplayLink.frameInterval = _frameInterval;
    });


    SP_EXECUTE_ON_OSX
    ({
        dispatch_async(_queue, ^
         {
             if (_cvDisplayLink)
             {
                 CVDisplayLinkStop(_cvDisplayLink);
                 CVDisplayLinkRelease(_cvDisplayLink);
                 _cvDisplayLink = NULL;
             }

             CVDisplayLinkCreateWithActiveCGDisplays(&_cvDisplayLink);
             CVDisplayLinkSetOutputCallback(_cvDisplayLink, (CVDisplayLinkOutputCallback)cvDisplayLinkOutputCallback, self);
         });
    });
}

- (void)teardown
{
    SP_EXECUTE_ON_IOS
    ({
        [_caDisplayLink invalidate];
        [_caDisplayLink release];
        _caDisplayLink = nil;
    });

    SP_EXECUTE_ON_OSX
    ({
        if (_cvDisplayLink)
        {
            dispatch_async(_queue, ^
             {
                 CVDisplayLinkStop(_cvDisplayLink);
                 CVDisplayLinkRelease(_cvDisplayLink);
                 _cvDisplayLink = NULL;
             });
        }
    });
}

- (void)start
{
    _averageFrameTime = 0;
    _frameCountBeginTime = 0;
    _frameCount = 0;

    SP_EXECUTE_ON_IOS
    ({
        if (_queue == dispatch_get_main_queue())
        {
            [(id)_queue release];
            _queue = nil;
        }

        [_caDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });

    SP_EXECUTE_ON_OSX
    ({
        dispatch_async(_queue, ^
         {
             CVDisplayLinkStart(_cvDisplayLink);
         });
    });
}

- (void)restart
{
    [self setup];
    [self start];
}

#pragma mark Callbacks

#if SP_TARGET_IOS
- (void)caDisplayLinkCallback
{
    _duration  = _caDisplayLink.duration;
    _timestamp = _caDisplayLink.timestamp;

    [self callbackForNextFrame:_timestamp + (_duration * (double)_frameInterval)];
}
#else
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

        spDisplayLink.timestamp = currentTime;
        spDisplayLink.duration  = (outputTime - nowTime);

        [spDisplayLink callbackForNextFrame:currentTime + (spDisplayLink.duration * (double)spDisplayLink.frameInterval)];
    }

    [spDisplayLink release];
    return kCVReturnSuccess;
}
#endif

- (void)callbackForNextFrame:(double)frameTime
{
    if (!_paused)
    {
        if (OSAtomicAdd32(1, &_queuedFrameCount) <= _maxQueuedFrameCount || _maxQueuedFrameCount == 0)
        {
            if (_queue)
            {
                if (_asynchronous)
                {
                    dispatch_async(_queue, ^
                     {
                         _block();
                         OSAtomicAdd32(-1, &_queuedFrameCount);
                     });
                }
                else
                {
                    dispatch_sync(_queue, ^
                     {
                         _block();
                         OSAtomicAdd32(-1, &_queuedFrameCount);
                     });
                }
            }
            else
            {
                _block();
                OSAtomicAdd32(-1, &_queuedFrameCount);
            }

            _frameCount++;
            if (_frameCount >= 4)
            {
                _averageFrameTime = (frameTime - _frameCountBeginTime) / _frameCount;
                _frameCountBeginTime = frameTime;
                _frameCount = 0;
            }
        }
        else
        {
            OSAtomicAdd32(-1, &_queuedFrameCount);
        }
    }
}

@end
