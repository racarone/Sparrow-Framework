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

// --- private interaface --------------------------------------------------------------------------

@interface SPViewController()

- (void)purgePools;
- (void)createRoot;
- (void)readjustStageSize;

@property (nonatomic, readonly) GLKView *glkView;

@end


// --- class implementation ------------------------------------------------------------------------

@implementation SPViewController
{
    SPContext *_context;
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
    
    double _lastTouchTimestamp;
    float _contentScaleFactor;
    float _viewScaleFactor;
    BOOL _supportHighResolutions;
    BOOL _doubleOnPad;
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
    [SPTexture purgeCache];
    [self purgePools];
    [SPContext setCurrentContext:nil];
    [Sparrow setCurrentController:nil];

    if (_resourceQueue)
        dispatch_release(_resourceQueue);
    
    [_context release];
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
    _contentScaleFactor = 1.0f;
    _stage = [[SPStage alloc] init];
    _juggler = [[SPJuggler alloc] init];
    _touchProcessor = [[SPTouchProcessor alloc] initWithRoot:_stage];
    _programs = [[NSMutableDictionary alloc] init];
    _context = [[SPContext alloc] init];
    
    if (!_context || ![SPContext setCurrentContext:_context])
        NSLog(@"Could not create render context");
    
    _support = [[SPRenderSupport alloc] init];
    
    [Sparrow setCurrentController:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self glkView].context = _context.nativeContext;
}

#pragma mark Methods

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
         _resourceContext = [[SPContext alloc] initWithSharegroup:_context.sharegroup];
    if (!_resourceQueue)
         _resourceQueue = dispatch_queue_create("Sparrow-ResourceQueue", NULL);
    
    dispatch_async(_resourceQueue, ^
    {
        [SPContext setCurrentContext:_resourceContext];
        block();
    });
}

#pragma mark GLKViewDelegate Protocol

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
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
        [SPContext setCurrentContext:_context];
        
        glDisable(GL_CULL_FACE);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        
        [_support nextFrame];
        [_stage render:_support];
        [_support finishQuadBatch];
        
        if (_statsDisplay)
            _statsDisplay.numDrawCalls = _support.numDrawCalls - 2; // stats display requires 2 itself
        
        #if DEBUG
        [SPRenderSupport checkForOpenGLError];
        #endif
    }
}

- (void)update
{
    @autoreleasepool
    {
        double passedTime = self.timeSinceLastUpdate;
        
        [Sparrow setCurrentController:self];
        [_stage advanceTime:passedTime];
        [_juggler advanceTime:passedTime];
    }
}

#pragma mark UIViewController

- (void)didReceiveMemoryWarning
{
    [self purgePools];
    [_support purgeBuffers];
    [super didReceiveMemoryWarning];
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
                touch.nativeTouch = uiTouch;
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

- (void)setMultitouchEnabled:(BOOL)multitouchEnabled
{
    self.view.multipleTouchEnabled = multitouchEnabled;
}

- (BOOL)multitouchEnabled
{
    return self.view.multipleTouchEnabled;
}

- (NSInteger)drawableWidth
{
    return self.glkView.drawableWidth;
}

- (NSInteger)drawableHeight
{
    return self.glkView.drawableHeight;
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

- (GLKView *)glkView
{
    return (GLKView *)self.view;
}

@end
