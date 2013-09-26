//
//  SPViewControllerMac.m
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
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

#import "SPViewController_Internal.h"
#import "SPViewControllerMac.h"

@interface SPViewControllerMac ()

- (void)updateAndDraw;

@property (nonatomic, readonly) SPViewMac* glView;
@property (nonatomic, strong)   NSScreen*  screen;

@end

static CVReturn __Heartbeat(CVDisplayLinkRef displayLink, const CVTimeStamp* inNow, const CVTimeStamp* inOutputTime,
                            CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
	SPViewControllerMac* view = (SPViewControllerMac*)displayLinkContext;
    [view updateAndDraw];
	return kCVReturnSuccess;
}

@implementation SPViewControllerMac
{
    BOOL                _displayLinkPaused;
    BOOL                _nextDeltaTimeZero;
    BOOL                _firstResumeOccurred;
    BOOL                _lastResumeOccurred;
    BOOL                _lastUpdateOccurred;
    BOOL                _lastDrawOccurred;
    BOOL                _pauseOnWillResignActive;
    BOOL                _resumeOnDidBecomeActive;
    BOOL                _viewIsVisible;

    NSInteger           _screenFramesPerSecond;
    NSInteger           _frameInterval;
    NSInteger           _preferredFramesPerSecond;
    NSInteger           _framesPerSecond;
    NSInteger           _framesDisplayed;

    NSTimeInterval      _timeSinceFirstResumeStartTime;
    NSTimeInterval      _timeSinceLastResumeStartTime;
    NSTimeInterval      _timeSinceLastUpdatePreviousTime;
    NSTimeInterval      _timeSinceLastDrawPreviousTime;
    NSTimeInterval      _timeSinceFirstResume;
    NSTimeInterval      _timeSinceLastResume;
    NSTimeInterval      _timeSinceLastUpdate;
    NSTimeInterval      _timeSinceLastDraw;
    NSTimeInterval      _deltaTime;
    NSTimeInterval      _lastDeltaTime;
    NSTimeInterval      _secondsPerFrame;

    SPViewMac*          _existingView;
	CVDisplayLinkRef    _displayLink;
}

- (instancetype)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        [self initCommon];
        [self configureNotifications];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    _pauseOnWillResignActive = NO;
    _resumeOnDidBecomeActive = NO;
    [self configureNotifications];

    CVDisplayLinkStop(_displayLink);
    CVDisplayLinkRelease(_displayLink);
    _displayLink = nil;

    [super dealloc];
}

- (void)initializeContext
{
    NSOpenGLPixelFormatAttribute attrs[] =
	{
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFADepthSize, 24,
		// Must specify the 3.2 Core Profile to use OpenGL 3.2
        // NSOpenGLPFAOpenGLProfile,
        // NSOpenGLProfileVersion3_2Core,
		0
	};

    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    SPContext* context = [[SPContext alloc] initWithFormat:pixelFormat shareContext:nil];

	// When we're using a CoreProfile context, crash if we call a legacy OpenGL function
	// This will make it much more obvious where and when such a function call is made so
	// that we can remove such calls.
	CGLEnable((CGLContextObj)[context CGLContextObj], kCGLCECrashOnRemovedFunctions);

    [self.glView setPixelFormat:pixelFormat];
    [pixelFormat release];

    [self.glView setOpenGLContext:context];
    [context release];

#if SUPPORT_RETINA_RESOLUTION
    // Opt-In to Retina resolution
    [self setWantsBestResolutionOpenGLSurface:YES];
#endif

    self.textureLoader = [[GLKTextureLoader alloc] initWithShareContext:self.context];
}

- (void)readjustStageSize
{
    CGSize viewSize = self.view.bounds.size;
    self.stage.width  = viewSize.width / self.contentScaleFactor;
    self.stage.height = viewSize.height / self.contentScaleFactor;
}

- (void)loadView
{
    if (![self nibName])
    {
        UIScreen* screen = [UIScreen mainScreen];
        CGRect screenRect = CGRectZero;

        if (screen) screenRect = [screen frame];
        if ([self wantsFullScreenLayout])
            if (screen) screenRect = [screen bounds];

        SPViewMac* view = [[SPViewMac alloc] initWithFrame:screenRect];
        //[view setAutoresizingMask:NSViewAutoresizingFlexibleWidth | NSViewAutoresizingFlexibleHeight];
        [self setView:view];
    }
    else
    {
        [super loadView];

        if (![_existingView isKindOfClass:[SPViewMac class]])
        {
            [NSException raise:NSInternalInconsistencyException
                        format:@"%@ loaded the \"%@\" nib but didn't get a FLEAGLView.",
             [NSString stringWithFormat:@"-[%@ %@]",
              NSStringFromClass([SPViewControllerMac class]),
              NSStringFromSelector(@selector(loadView))],
             [self nibName]];
        }
    }

    if (_existingView)
    {
        if (![_existingView delegate]) {
            [_existingView setDelegate:self];
        }
    }

    [self createDisplayLinkForScreen:nil];
}

- (void)setResumeOnDidBecomeActive:(BOOL)resumeOnDidBecomeActive
{
    _resumeOnDidBecomeActive = resumeOnDidBecomeActive;
    [self __configureNotifications];
}

- (void)setPauseOnWillResignActive:(BOOL)pauseOnWillResignActive
{
    _pauseOnWillResignActive = pauseOnWillResignActive;
    [self __configureNotifications];
}

#pragma mark properties

- (BOOL)isPaused
{
    return !CVDisplayLinkIsRunning(_displayLink);
}

- (void)setPaused:(BOOL)paused
{
    if (_displayLink)
    {
        if (!(paused | _firstResumeOccurred))
        {
            _timeSinceFirstResumeStartTime = CACurrentMediaTime();
            _firstResumeOccurred = YES;
        }

        if (!(paused | _lastResumeOccurred))
        {
            _timeSinceFirstResumeStartTime = CACurrentMediaTime();
            _lastResumeOccurred = YES;
        }

        if (paused == YES)
        {
            _lastResumeOccurred = NO;
            _lastUpdateOccurred = NO;
            _lastDrawOccurred = NO;
        }

        if (paused == YES)
            CVDisplayLinkStop(_displayLink);
        else
            CVDisplayLinkStart(_displayLink);
    }
}

- (void)setView:(SPViewMac*)view
{
    if (_existingView != view)
    {
        _existingView = view;
        [super setView:view];

        if ([_existingView isKindOfClass:[SPViewMac class]])
        {
            if (![_existingView delegate]) {
                [_existingView setDelegate:self];
            }
        }
    }
}

#pragma mark - internal

- (void)initCommon
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_updateScreenIfChanged)
                                                 name:NSWindowDidChangeScreenNotification
                                               object:nil];

    _pauseOnWillResignActive = YES;
    _resumeOnDidBecomeActive = YES;
    _displayLinkPaused = YES;
}

- (void)configureNotifications
{
    NSNotificationCenter* defaultCenter = [NSNotificationCenter defaultCenter];

    if (_pauseOnWillResignActive)
    {
        [defaultCenter addObserver:self
                          selector:@selector(__pauseByNotification)
                              name:NSWindowDidResignMainNotification
                            object:nil];
    }
    else
    {
        [defaultCenter removeObserver:self
                                 name:NSWindowDidResignMainNotification
                               object:nil];
    }

    if (_resumeOnDidBecomeActive) {
        [defaultCenter addObserver:self
                          selector:@selector(__resumeByNotification)
                              name:NSWindowDidBecomeMainNotification
                            object:nil];
    }
    else
    {
        [defaultCenter removeObserver:self
                                 name:NSWindowDidBecomeMainNotification
                               object:nil];
    }

}

- (void)createDisplayLinkForScreen:(NSScreen*)screen
{
	// Create a display link capable of being used with all active displays
	CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);

	// Set the renderer output callback function
	CVDisplayLinkSetOutputCallback(_displayLink, &__Heartbeat, self);

	// Set the display link for the current renderer
	CGLContextObj cglContext = (CGLContextObj)[self.glView.openGLContext CGLContextObj];
	CGLPixelFormatObj cglPixelFormat = (CGLPixelFormatObj)[self.glView.pixelFormat CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, cglContext, cglPixelFormat);

	// Activate the display link
	CVDisplayLinkStart(_displayLink);

//	// Register to be notified when the window closes so we can stop the displaylink
//	[[NSNotificationCenter defaultCenter] addObserver:self
//											 selector:@selector(windowWillClose:)
//												 name:NSWindowWillCloseNotification
//											   object:[self window]];
//
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(surfaceNeedsUpdate:)
//                                                 name:NSViewGlobalFrameDidChangeNotification
//                                               object:self];
}

- (void)resumeByNotification
{
    if (_viewIsVisible)
        [self setPaused:NO];
}

- (void)pauseByNotification
{
    [self setPaused:YES];
}

- (void)updateAndDraw
{
    if (_lastDrawOccurred)
    {
        NSTimeInterval currentTime = CACurrentMediaTime();
        _timeSinceLastUpdate = currentTime - _timeSinceLastUpdatePreviousTime;
        _timeSinceLastUpdatePreviousTime = currentTime;
    }
    else
    {
        _timeSinceLastUpdate = 0.0;
        _timeSinceLastUpdatePreviousTime = CACurrentMediaTime();
        _lastDrawOccurred = YES;
    }

    [self advanceTime:_timeSinceLastUpdate];

    if (_existingView)
    {
        if (_lastDrawOccurred)
        {
            NSTimeInterval currentTime = CACurrentMediaTime();
            _timeSinceLastDraw = currentTime - _timeSinceLastDrawPreviousTime;
            _timeSinceLastDrawPreviousTime = currentTime;
        }
        else
        {
            _timeSinceLastDraw = 0.0;
            _timeSinceLastDrawPreviousTime = CACurrentMediaTime();
            _lastDrawOccurred = YES;
        }

        [_existingView display];
        ++_framesDisplayed;
    }
}

@end
