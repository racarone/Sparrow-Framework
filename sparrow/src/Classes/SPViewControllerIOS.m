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

#import "SparrowClass_Internal.h"
#import "SPContext.h"
#import "SPEnterFrameEvent.h"
#import "SPJuggler.h"
#import "SPProgram.h"
#import "SPRenderSupport.h"
#import "SPResizeEvent.h"
#import "SPStage.h"
#import "SPStatsDisplay.h"
#import "SPTexture.h"
#import "SPTouch_Internal.h"
#import "SPTouchProcessor.h"
#import "SPViewControllerIOS.h"
#import "SPViewController_Internal.h"

// --- private interaface --------------------------------------------------------------------------

@interface SPViewControllerIOS()

@property (nonatomic, readonly) GLKView* glkView;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPViewControllerIOS
{
    double                  _lastTouchTimestamp;
    float                   _viewScaleFactor;
    BOOL                    _doubleOnPad;
}

- (void)dealloc
{
    [self purgePools];
    [SPContext setCurrentContext:nil];
    [super dealloc];
}

- (void)initializeContext
{
    self.context = [[[SPContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2] autorelease];

    if (!self.context || ![SPContext setCurrentContext:self.context])
        NSLog(@"Could not create render context");

    self.textureLoader = [[[GLKTextureLoader alloc] initWithSharegroup:self.context.sharegroup] autorelease];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self glkView].context = self.context;
}

- (void)didReceiveMemoryWarning
{
    [self purgePools];
    [self.support purgeBuffers];
    [super didReceiveMemoryWarning];
}

- (void)purgePools
{
    [SPPoint purgePool];
    [SPRectangle purgePool];
    [SPMatrix purgePool];
}

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
    if (self.rootClass)
        [NSException raise:SP_EXC_INVALID_OPERATION
                    format:@"Sparrow has already been started"];

    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    
    self.rootClass = rootClass;
    self.supportHighResolutions = hd;
    _doubleOnPad = doubleOnPad;
    _viewScaleFactor = self.supportHighResolutions ? [[UIScreen mainScreen] scale] : 1.0f;
    self.contentScaleFactor = (_doubleOnPad && isPad) ? _viewScaleFactor * 2.0f : _viewScaleFactor;
}

- (void)readjustStageSize
{
    CGSize viewSize = self.view.bounds.size;
    self.stage.width  = viewSize.width  * _viewScaleFactor / self.contentScaleFactor;
    self.stage.height = viewSize.height * _viewScaleFactor / self.contentScaleFactor;
}

#pragma mark - GLKViewDelegate

- (void)glkView:(GLKView*)view drawInRect:(CGRect)rect
{
    [super renderInRect:rect];
}

- (void)update
{
    [super advanceTime:self.timeSinceLastUpdate];
}

- (NSInteger)backBufferWidth
{
    return self.glkView.drawableWidth;
}

- (NSInteger)backBufferHeight
{
    return self.glkView.drawableHeight;
}

#pragma mark - Touch Processing

- (void)setMultitouchEnabled:(BOOL)multitouchEnabled
{
    self.view.multipleTouchEnabled = multitouchEnabled;
}

- (BOOL)multitouchEnabled
{
    return self.view.multipleTouchEnabled;
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    [self processTouchEvent:event];
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
    [self processTouchEvent:event];
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    [self processTouchEvent:event];
}

- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event
{
    _lastTouchTimestamp -= 0.0001f; // cancelled touch events have an old timestamp -> workaround
    [self processTouchEvent:event];
}

- (void)processTouchEvent:(UIEvent*)event
{
    if (!self.paused && _lastTouchTimestamp != event.timestamp)
    {
        @autoreleasepool
        {
            CGSize viewSize = self.view.bounds.size;
            float xConversion = self.stage.width / viewSize.width;
            float yConversion = self.stage.height / viewSize.height;
            
            // convert to SPTouches and forward to stage
            NSMutableSet* touches = [NSMutableSet set];
            double now = CACurrentMediaTime();
            for (UITouch* uiTouch in [event touchesForView:self.view])
            {
                CGPoint location = [uiTouch locationInView:self.view];
                CGPoint previousLocation = [uiTouch previousLocationInView:self.view];
                SPTouch* touch = [SPTouch touch];
                touch.timestamp = now; // timestamp of uiTouch not compatible to Sparrow timestamp
                touch.globalX = location.x * xConversion;
                touch.globalY = location.y * yConversion;
                touch.previousGlobalX = previousLocation.x * xConversion;
                touch.previousGlobalY = previousLocation.y * yConversion;
                touch.tapCount = uiTouch.tapCount;
                touch.phase = (SPTouchPhase)uiTouch.phase;
                touch.nativeTouch = uiTouch;
                [touches addObject:touch];
            }
            [self.touchProcessor processTouches:touches];
            _lastTouchTimestamp = event.timestamp;
        }
    }
}

#pragma mark - Auto Rotation

// The following methods implement what I would expect to be the default behaviour of iOS:
// The orientations that you activated in the application plist file are automatically rotated to.

- (NSUInteger)supportedInterfaceOrientations
{
    NSArray* supportedOrientations =
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
    NSArray* supportedOrientations =
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
    SPStage* stage = self.stage;
    
    float newWidth  = isPortrait ? MIN(stage.width, stage.height) :
                                   MAX(stage.width, stage.height);
    float newHeight = isPortrait ? MAX(stage.width, stage.height) :
                                   MIN(stage.width, stage.height);
    
    if (newWidth != stage.width)
    {
        stage.width  = newWidth;
        stage.height = newHeight;
        
        SPEvent* resizeEvent = [[SPResizeEvent alloc] initWithType:kSPEventTypeResize width:newWidth height:newHeight animationTime:duration];
        [stage broadcastEvent:resizeEvent];
        [resizeEvent release];
    }
}

#pragma mark - Properties

- (GLKView*)glkView
{
    return (GLKView*)self.view;
}

@end
