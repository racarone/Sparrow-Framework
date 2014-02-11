//
//  SPViewController.m
//  Sparrow
//
//  Created by Daniel Sperl on 26.01.13.
//  Copyright 2013 Gamua. All rights reserved.
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

#pragma mark - SPViewController

@interface SPViewController ()

@property (nonatomic, readonly) SPView *spView;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPViewController
{
    SPView *_existingView;
    SPDisplayLink *_displayLink;
    Class _rootClass;
    SPStage *_stage;
    SPDisplayObject *_root;
    SPJuggler *_juggler;
    SPTouchProcessor *_touchProcessor;
    SPRenderSupport *_support;
    SPRootCreatedBlock _onRootCreated;
    SPStatsDisplay *_statsDisplay;
    NSMutableDictionary *_programs;

    dispatch_queue_t _resourceQueue;
    SPContext *_resourceContext;

    int _framesDisplayed;
    int _targetFramesPerSecond;
    float _contentScaleFactor;
    float _viewScaleFactor;
    double _previousFrameTime;
    double _deltaTime;
    double _lastTouchTimestamp;
    BOOL _paused;
    BOOL _supportHighResolutions;
    BOOL _doubleOnPad;
    BOOL _viewIsVisible;
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
    [SPTexture purgeCache];
    [self purgePools];

    [SPContext setCurrentContext:nil];
    [Sparrow setCurrentController:nil];

    [(id)_resourceQueue release];
    [_resourceContext release];
    [_stage release];
    [_root release];
    [_juggler release];
    [_touchProcessor release];
    [_support release];
    [_onRootCreated release];
    [_statsDisplay release];
    [_programs release];
    [super dealloc];
}

- (void)setup
{
    _paused = YES;
    _contentScaleFactor = 1.0f;
    _stage = [[SPStage alloc] init];
    _juggler = [[SPJuggler alloc] init];
    _touchProcessor = [[SPTouchProcessor alloc] initWithRoot:_stage];
    _programs = [[NSMutableDictionary alloc] init];
    _support = [[SPRenderSupport alloc] init];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(pauseByNotification:)
    	name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(resumeByNotification:)
    	name:UIApplicationDidBecomeActiveNotification object:nil];

    [self createDisplayLink];
    [Sparrow setCurrentController:self];
}

#pragma mark Startup

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
    _supportHighResolutions = hd;
    _doubleOnPad = doubleOnPad;
    _viewScaleFactor = _supportHighResolutions ? [[UIScreen mainScreen] scale] : 1.0f;
    _contentScaleFactor = (_doubleOnPad && isPad) ? _viewScaleFactor * 2.0f : _viewScaleFactor;
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
         _resourceContext = [[SPContext alloc] initWithSharegroup:_existingView.context.sharegroup];

    if (!_resourceQueue)
         _resourceQueue = dispatch_queue_create("Sparrow-ResourceQueue", NULL);
    
    dispatch_async(_resourceQueue, ^
    {
        [SPContext setCurrentContext:_resourceContext];
        block();
    });
}

#pragma mark View Controller

- (void)didReceiveMemoryWarning
{
    [self purgePools];
    [_support purgeBuffers];

    [super didReceiveMemoryWarning];
}

- (void)loadView
{
    if (self.nibName && self.nibBundle)
    {
        [super loadView];

        if (![_existingView isKindOfClass:[SPView class]])
            [NSException raise:NSInternalInconsistencyException
                        format:@"Loaded the nib but didn't get an SPView"];
    }
    else
    {
        SPView *view = [[SPView alloc] initWithFrame:_existingView.frame context:_existingView.context];
        [view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self setView:view];
    }
}

- (void)setView:(SPView *)view
{
    if (view != _existingView)
    {
        _existingView = view;
        [super setView:view];

        if ([_existingView isKindOfClass:[SPView class]] && !_existingView.delegate)
            _existingView.delegate = self;
    }
}

- (void)viewDidLoad
{
    [self stopDisplayLink];
}

- (void)viewDidUnload
{
    [self startDisplayLink];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self stopDisplayLink];
    _viewIsVisible = YES;

    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    _viewIsVisible = NO;
    [self startDisplayLink];
}

#pragma mark Notifications

- (void)pauseByNotification:(NSNotification *)notification
{
    self.paused = YES;
}

- (void)resumeByNotification:(NSNotification *)notification
{
    if (_viewIsVisible)
        self.paused = NO;
}

#pragma mark Display

- (void)createDisplayLink
{
    [_displayLink release];

    __block id weakSelf = self;
    _displayLink = [[SPDisplayLink alloc] initWithBlock:^(double frameTime) {
        [weakSelf updateAndDraw:frameTime];
    }];

    _displayLink.asynchronous = NO;
    [self setTargetFramesPerSecond:60];
}

- (void)startDisplayLink
{
    _displayLink.paused = NO;
}

- (void)stopDisplayLink
{
    _displayLink.paused = YES;
}

- (void)updateAndDraw:(double)frameTime
{
    _existingView.enableSetNeedsDisplay = NO;

    if (_previousFrameTime <= 0.0)
        _previousFrameTime = frameTime - 0.004;

    double currentTime = CACurrentMediaTime();
    if (frameTime - currentTime >= -0.025)
        currentTime = frameTime;

    _deltaTime = currentTime - _previousFrameTime;
    _previousFrameTime = currentTime;

    if (_deltaTime >= 0.004)
    {
        [self update];
        [_existingView render];
    }
}

- (void)update
{
    @autoreleasepool
    {
        [Sparrow setCurrentController:self];
        [_stage advanceTime:_deltaTime];
        [_juggler advanceTime:_deltaTime];
    }
}

#pragma mark SPViewDelegate Protocol

- (void)renderRect:(CGRect)rect view:(SPView *)view
{
    @autoreleasepool
    {
        if (!_root)
        {
            // ideally, we'd do this in 'viewDidLoad', but when iOS starts up in landscape mode,
            // the view width and height are swapped. In this method, however, they are correct.
            
            [self readjustStageSize];
            [self createRoot];
        }
        
        [Sparrow setCurrentController:self];
        [_support nextFrame];
        [_stage render:_support];
        [_support finishQuadBatch];
        
        if (_statsDisplay)
            _statsDisplay.numDrawCalls = _support.numDrawCalls - 2; // stats display requires 2 itself
        
      #if DEBUG
        [SPRenderSupport checkForOpenGLError];
      #endif

        ++_framesDisplayed;
    }
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
    if (!self.paused && _lastTouchTimestamp != event.timestamp)
    {
        @autoreleasepool
        {
            CGSize viewSize = self.view.bounds.size;
            float xConversion = _stage.width / viewSize.width;
            float yConversion = _stage.height / viewSize.height;
            
            // convert to SPTouches and forward to stage
            NSMutableSet *touches = [NSMutableSet set];
            double now = CACurrentMediaTime();
            for (UITouch *uiTouch in [event touchesForView:self.view])
            {
                CGPoint location = [uiTouch locationInView:self.view];
                CGPoint previousLocation = [uiTouch previousLocationInView:self.view];
                SPTouch *touch = [SPTouch touch];
                touch.timestamp = now; // timestamp of uiTouch not compatible to Sparrow timestamp
                touch.globalX = location.x * xConversion;
                touch.globalY = location.y * yConversion;
                touch.previousGlobalX = previousLocation.x * xConversion;
                touch.previousGlobalY = previousLocation.y * yConversion;
                touch.tapCount = (int)uiTouch.tapCount;
                touch.phase = (SPTouchPhase)uiTouch.phase;
                touch.touchID = (size_t)uiTouch;
                [touches addObject:touch];
            }

            [_touchProcessor processTouches:touches];
            _lastTouchTimestamp = event.timestamp;
        }
    }
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
                                         duration:(double)duration
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

- (SPContext *)context
{
    return _existingView.context;
}

- (void)setPaused:(BOOL)paused
{
    if (paused != _paused)
    {
        _paused = paused;

        if (_paused)
        {
            [_existingView setEnableSetNeedsDisplay:YES];
            [self stopDisplayLink];
            _framesDisplayed = 0;
        }
        else
        {
            _framesDisplayed = 0;
            [self startDisplayLink];
        }
    }
}

- (void)setMultitouchEnabled:(BOOL)multitouchEnabled
{
    self.view.multipleTouchEnabled = multitouchEnabled;
}

- (BOOL)multitouchEnabled
{
    return self.view.multipleTouchEnabled;
}

- (BOOL)showStats
{
    return _statsDisplay.visible;
}

- (void)setShowStats:(BOOL)showStats
{
    if (showStats && !_statsDisplay)
    {
        _statsDisplay = [[SPStatsDisplay alloc] init];
        [_stage addChild:_statsDisplay];
    }

    _statsDisplay.visible = showStats;
}

- (void)setTargetFramesPerSecond:(int)targetFramesPerSecond
{
    if (targetFramesPerSecond < 1)
        targetFramesPerSecond = 1;

    int frameInterval = ceilf(60.0f / (float)targetFramesPerSecond);
    _targetFramesPerSecond = 60 / frameInterval;
    _displayLink.frameInterval = frameInterval;
}

- (int)drawableWidth
{
    return _existingView.drawableWidth;
}

- (int)drawableHeight
{
    return _existingView.drawableHeight;
}

#pragma mark Private

- (void)purgePools
{
    [SPPoint purgePool];
    [SPRectangle purgePool];
    [SPMatrix purgePool];
}

- (void)createRoot
{
    if (!_root)
    {
        _root = [[_rootClass alloc] init];

        if ([_root isKindOfClass:[SPStage class]])
            [NSException raise:SPExceptionInvalidOperation
                        format:@"Root extends 'SPStage' but is expected to extend 'SPSprite' "
                               @"instead (different to Sparrow 1.x)"];
        else
        {
            [_stage addChild:_root atIndex:0];

            if (_onRootCreated)
            {
                _onRootCreated(_root);
                SP_RELEASE_AND_NIL(_onRootCreated);
            }
        }
    }
}

- (void)readjustStageSize
{
    CGSize viewSize = self.view.bounds.size;
    _stage.width  = viewSize.width  * _viewScaleFactor / _contentScaleFactor;
    _stage.height = viewSize.height * _viewScaleFactor / _contentScaleFactor;
}

- (SPView *)spView
{
    return (SPView *)self.view;
}

@end
