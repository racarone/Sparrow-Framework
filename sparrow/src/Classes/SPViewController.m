//
//  SPViewController.m
//  Sparrow
//
//  Created by Daniel Sperl on 26.01.13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass_Internal.h>
#import <Sparrow/SPContext.h>
#import <Sparrow/SPDisplayLink.h>
#import <Sparrow/SPEnterFrameEvent.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPJuggler.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPProgram.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPRenderSupport.h>
#import <Sparrow/SPResizeEvent.h>
#import <Sparrow/SPStage_Internal.h>
#import <Sparrow/SPStatsDisplay.h>
#import <Sparrow/SPTexture.h>
#import <Sparrow/SPTouchProcessor.h>
#import <Sparrow/SPTouch_Internal.h>
#import <Sparrow/SPViewController.h>

NSString *const SPNotificationContextCreated = @"SPNotificationContextCreated";
NSString *const SPNotificationRootCreated    = @"SPNotificationRootCreated";

// --- class implementation ------------------------------------------------------------------------

@implementation SPViewController
{
    Class _rootClass;
    SPStage *_stage;
    SPDisplayObject *_root;
    SPJuggler *_juggler;
    SPTouchProcessor *_touchProcessor;
    SPRenderSupport *_support;
    SPStatsDisplay *_statsDisplay;
    NSMutableDictionary *_programs;

    SPDisplayLink *_displayLink;
    SPContext *_context;
    dispatch_queue_t _renderQueue;
    SPContext *_resourceContext;
    dispatch_queue_t _resourceQueue;
    
    double _lastTouchTimestamp;
    double _lastFrameTimestamp;
    float _contentScaleFactor;
    float _viewScaleFactor;
    BOOL _doubleOnPad;
    BOOL _showStats;
    BOOL _paused;
    BOOL _rendering;
}

#pragma mark Initialization

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setup];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithNibName:nil bundle:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self purgePools];

    [(id)_resourceQueue release];
    [(id)_renderQueue release];
    [_context release];
    [_resourceContext release];
    [_stage release];
    [_root release];
    [_juggler release];
    [_touchProcessor release];
    [_support release];
    [_statsDisplay release];
    [_programs release];

    [SPContext setCurrentContext:nil];
    [Sparrow setCurrentController:nil];

    [super dealloc];
}

- (void)setup
{
    _contentScaleFactor = 1.0f;
    _stage = [[SPStage alloc] init];
    _juggler = [[SPJuggler alloc] init];
    _touchProcessor = [[SPTouchProcessor alloc] initWithStage:_stage];
    _programs = [[NSMutableDictionary alloc] init];
    _resourceQueue = dispatch_queue_create("Sparrow-ResourceQueue", NULL);
    _resourceQueue = dispatch_queue_create("Sparrow-RenderQueue", NULL);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMemoryWarning:)
		name:UIApplicationDidReceiveMemoryWarningNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive:)
		name:UIApplicationDidBecomeActiveNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResign:)
    	name:UIApplicationWillResignActiveNotification object:nil];

    [self makeCurrent];
    [self setupRenderCallback];

    self.rendering = YES;
}

- (void)setupContext
{
    _context = [[[SPContext alloc] initWithShareContext:[SPContext globalShareContext]] autorelease];
    if (!_context || ![SPContext setCurrentContext:_context])
        NSLog(@"Could not create render context");

    self.view.context = _context;

    [[NSNotificationCenter defaultCenter]
     postNotificationName:SPNotificationContextCreated object:_context];

    _support = [[SPRenderSupport alloc] init];
    [self readjustStageSize];
    [self setupRoot];

    // the stats display could not be shown before now, since it requires a context.
    self.showStats = _showStats;
}

- (void)setupRenderCallback
{
    SP_RELEASE_AND_NIL(_displayLink);

    __block SPViewController *weakSelf = self;
    _displayLink = [[SPDisplayLink alloc] initWithQueue:_renderQueue block:^
     {
         if (!weakSelf.paused) [weakSelf nextFrame];
         else                  [weakSelf render];
     }];
}

- (void)setupRoot
{
    if (!_root)
    {
        _root = [[_rootClass alloc] init];

        if (![_root isKindOfClass:[SPDisplayObject class]])
            [NSException raise:SPExceptionInvalidOperation
                        format:@"Invalid root class: %@", NSStringFromClass(_rootClass)];

        if ([_root isKindOfClass:[SPStage class]])
            [NSException raise:SPExceptionInvalidOperation
                        format:@"Root extends 'SPStage' but is expected to extend 'SPSprite' "
                               @"instead (different to Sparrow 1.x)"];

        [_stage addChild:_root atIndex:0];

        [[NSNotificationCenter defaultCenter]
         postNotificationName:SPNotificationRootCreated object:_root];
    }
}

#pragma mark View Controller

- (void)loadView
{
    if (![self nibName])
    {
        CGRect screenRect;
        if ([self wantsFullScreenLayout]) screenRect = [[UIScreen mainScreen] bounds];
        else                              screenRect = [[UIScreen mainScreen] applicationFrame];

        SPView *view = [[SPView alloc] initWithFrame:screenRect];
        [view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self setView:view];
    }
    else
    {
        [super loadView];

        if (![self.view isKindOfClass:[SPView class]])
            [NSException raise:SPExceptionInvalidOperation
                        format:@"Loaded view nib, but it wasn't an SPView class"];
    }

    self.view.viewController = self;
}

#pragma mark Notifications

- (void)onActive:(NSNotification *)notification
{
    self.rendering = YES;
}

- (void)onResign:(NSNotification *)notification
{
    self.rendering = NO;
}

- (void)onMemoryWarning:(NSNotification *)notification
{
    [self purgePools];
    [_support purgeBuffers];
}

#pragma mark Start

- (void)startWithRoot:(Class)rootClass
{
    [self startWithRoot:rootClass supportHighResolutions:YES];
}

- (void)startWithRoot:(Class)rootClass supportHighResolutions:(BOOL)hd
{
    [self startWithRoot:rootClass supportHighResolutions:hd doubleOnPad:NO];
}

- (void)startWithRoot:(Class)rootClass supportHighResolutions:(BOOL)hd doubleOnPad:(BOOL)doubleOnPad
{
    if (_rootClass)
        [NSException raise:SPExceptionInvalidOperation
                    format:@"Sparrow has already been started"];

    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    
    _rootClass = rootClass;
    _doubleOnPad = doubleOnPad;
    _viewScaleFactor = hd ? [[UIScreen mainScreen] scale] : 1.0f;
    _contentScaleFactor = (_doubleOnPad && isPad) ? _viewScaleFactor * 2.0f : _viewScaleFactor;

    self.view.supportHighResolutions = hd;
    self.paused = NO;
}

#pragma mark Methods

- (void)makeCurrent
{
    [Sparrow setCurrentController:self];
}

- (void)nextFrame
{
    double now = _displayLink.timestamp;
    double passedTime = now - _lastFrameTimestamp;
    _lastFrameTimestamp = now;

    // to avoid overloading time-based animations, the maximum delta is truncated.
    if (passedTime > 1.0) passedTime = 1.0;

    [self advanceTime:passedTime];
    [self render];
}

- (void)render
{
    if (!_rendering)
        return;

    if (!_context)
        [self setupContext];

    if (!_context)
        return;

    @autoreleasepool
    {
        if ([_context makeCurrentContext])
        {
            [self makeCurrent];

            [_support nextFrame];
            [_support setRenderTarget:nil];
            [_stage render:_support];
            [_support finishQuadBatch];

            if (_statsDisplay)
                _statsDisplay.numDrawCalls = _support.numDrawCalls - 2; // stats display requires 2 itself

        #if DEBUG
            [SPRenderSupport checkForOpenGLError];
        #endif

            [_context present];
        }
        else NSLog(@"WARNING: Sparrow was unable to set the current rendering context.");
    }
}

- (void)advanceTime:(double)passedTime
{
    if (_paused)
        return;

    if (!_context)
        return;

    @autoreleasepool
    {
        [self makeCurrent];

        [_touchProcessor advanceTime:passedTime];
        [_stage advanceTime:passedTime];
        [_juggler advanceTime:passedTime];
    }
}

#pragma mark Program Management

- (void)registerProgram:(SPProgram *)program name:(NSString *)name
{
    _programs[name] = program;
}

- (void)unregisterProgram:(NSString *)name
{
    [_programs removeObjectForKey:name];
}

- (SPProgram *)programByName:(NSString *)name
{
    return _programs[name];
}

#pragma mark Other Methods

- (void)executeInResourceQueue:(dispatch_block_t)block
{
    if (!_resourceContext)
         _resourceContext = [[SPContext alloc] initWithShareContext:[SPContext globalShareContext]];
    
    dispatch_async(_resourceQueue, ^
    {
        [_resourceContext makeCurrentContext];
        block();
    });
}

#pragma mark Touch Processing

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self processTouchEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self processTouchEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self processTouchEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _lastTouchTimestamp -= 0.0001f; // cancelled touch events have an old timestamp -> workaround
    [self processTouchEvent:event];
}

- (void)processTouchEvent:(UIEvent *)event
{
    if (!_paused && _lastTouchTimestamp != event.timestamp)
    {
        @autoreleasepool
        {
            CGSize viewSize = self.view.bounds.size;
            float xConversion = _stage.width / viewSize.width;
            float yConversion = _stage.height / viewSize.height;
            
            // convert to SPTouches and forward to stage
            double now = CACurrentMediaTime();
            for (UITouch *uiTouch in [event touchesForView:self.view])
            {
                CGPoint location = [uiTouch locationInView:self.view];
                CGPoint previousLocation = [uiTouch previousLocationInView:self.view];

                SPTouch *touch = [SPTouch touchWithID:(size_t)uiTouch];
                touch.timestamp = now; // timestamp of uiTouch not compatible to Sparrow timestamp
                touch.globalX = location.x * xConversion;
                touch.globalY = location.y * yConversion;
                touch.previousGlobalX = previousLocation.x * xConversion;
                touch.previousGlobalY = previousLocation.y * yConversion;
                touch.tapCount = (int)uiTouch.tapCount;
                touch.phase = [self touchPhaseForUITouch:uiTouch];
                [_touchProcessor enqueueTouch:touch];
            }

            _lastTouchTimestamp = event.timestamp;
        }
    }
}

- (SPTouchPhase)touchPhaseForUITouch:(UITouch *)touch
{
    switch (touch.phase)
    {
        case UITouchPhaseBegan:      return SPTouchPhaseBegan; break;
        case UITouchPhaseMoved:      return SPTouchPhaseMoved; break;
        case UITouchPhaseStationary: return SPTouchPhaseStationary; break;
        case UITouchPhaseEnded:      return SPTouchPhaseEnded; break;
        case UITouchPhaseCancelled:  return SPTouchPhaseCancelled; break;
    }

    return SPNotFound;
}

#pragma mark Auto Rotation

// The following methods implement what I would expect to be the default behaviour of iOS:
// The orientations that you activated in the application plist file are automatically rotated to.

- (NSUInteger)supportedInterfaceOrientations
{
    NSArray *supportedOrientations =
    [[NSBundle mainBundle] infoDictionary][@"UISupportedInterfaceOrientations"];
    
    NSUInteger returnOrientations = 0;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortrait"])
        returnOrientations |= UIInterfaceOrientationMaskPortrait;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeLeft"])
        returnOrientations |= UIInterfaceOrientationMaskLandscapeLeft;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortraitUpsideDown"])
        returnOrientations |= UIInterfaceOrientationMaskPortraitUpsideDown;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeRight"])
        returnOrientations |= UIInterfaceOrientationMaskLandscapeRight;
    
    return returnOrientations;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    NSArray *supportedOrientations =
    [[NSBundle mainBundle] infoDictionary][@"UISupportedInterfaceOrientations"];
    
    return ((interfaceOrientation == UIInterfaceOrientationPortrait &&
             [supportedOrientations containsObject:@"UIInterfaceOrientationPortrait"]) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeLeft &&
             [supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeLeft"]) ||
            (interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown &&
             [supportedOrientations containsObject:@"UIInterfaceOrientationPortraitUpsideDown"]) ||
            (interfaceOrientation == UIInterfaceOrientationLandscapeRight &&
             [supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeRight"]));
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    // inform all display objects about the new game size
    BOOL isPortrait = UIInterfaceOrientationIsPortrait(interfaceOrientation);
    
    float newWidth  = isPortrait ? MIN(_stage.width, _stage.height) :
                                   MAX(_stage.width, _stage.height);
    float newHeight = isPortrait ? MAX(_stage.width, _stage.height) :
                                   MIN(_stage.width, _stage.height);
    
    if (newWidth != _stage.width)
    {
        _stage.width  = newWidth;
        _stage.height = newHeight;
        
        SPEvent *resizeEvent = [[SPResizeEvent alloc] initWithType:SPEventTypeResize
                               width:newWidth height:newHeight animationTime:duration];
        [_stage broadcastEvent:resizeEvent];
        [resizeEvent release];
    }
}

#pragma mark Properties

- (void)setRendering:(BOOL)rendering
{
    if (rendering != _rendering)
    {
        _rendering = rendering;
        _displayLink.paused = !rendering;
    }
}

- (void)setShowStats:(BOOL)showStats
{
    if (showStats && !_statsDisplay && _context)
    {
        _statsDisplay = [[SPStatsDisplay alloc] init];
        [_stage addChild:_statsDisplay];
    }

    _showStats = showStats;
    _statsDisplay.visible = showStats;
}

- (BOOL)supportHighResolutions
{
    return self.view.supportHighResolutions;
}

- (void)setSupportHighResolutions:(BOOL)supportHighResolutions
{
    self.view.supportHighResolutions = supportHighResolutions;
}

- (int)targetFramesPerSecond
{
    return 60 / _displayLink.frameInterval;
}

- (void)setTargetFramesPerSecond:(int)targetFramesPerSecond
{
    if (targetFramesPerSecond < 1) targetFramesPerSecond = 1;
    _displayLink.frameInterval = ceilf(60.0f / (float)targetFramesPerSecond);
}

#pragma mark Private

- (void)purgePools
{
    [SPPoint purgePool];
    [SPRectangle purgePool];
    [SPMatrix purgePool];
}

- (void)readjustStageSize
{
    CGSize viewSize = self.view.bounds.size;
    _stage.width  = viewSize.width  * _viewScaleFactor / _contentScaleFactor;
    _stage.height = viewSize.height * _viewScaleFactor / _contentScaleFactor;
}

@end
