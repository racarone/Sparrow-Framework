//
//  SPController.m
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
#import "SPTouchProcessor.h"
#import "SPViewController.h"
#import "SPViewController_Internal.h"

@implementation SPViewController
{
    SPContext*              _context;
    Class                   _rootClass;
    SPStage*                _stage;
    SPDisplayObject*        _root;
    SPJuggler*              _juggler;
    SPTouchProcessor*       _touchProcessor;
    SPRenderSupport*        _support;
    SPRootCreatedBlock      _onRootCreated;
    SPStatsDisplay*         _statsDisplay;
    NSMutableDictionary*    _programs;
    GLKTextureLoader*       _textureLoader;
    float                   _contentScaleFactor;
    BOOL                    _supportHighResolutions;
}

@synthesize rootClass               = _rootClass;
@synthesize support                 = _support;
@synthesize touchProcessor          = _touchProcessor;

@synthesize stage                   = _stage;
@synthesize juggler                 = _juggler;
@synthesize root                    = _root;
@synthesize context                 = _context;
@synthesize supportHighResolutions  = _supportHighResolutions;
@synthesize contentScaleFactor      = _contentScaleFactor;
@synthesize onRootCreated           = _onRootCreated;
@synthesize textureLoader           = _textureLoader;

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setup];
    }
    return self;
}

- (id)init
{
    if ((self = [super init]))
    {
        [self setup];
    }
    return self;
}

- (void)dealloc
{
    [Sparrow setCurrentController:nil];

    SP_RELEASE_AND_NIL(_stage);
    SP_RELEASE_AND_NIL(_root);
    SP_RELEASE_AND_NIL(_juggler);
    SP_RELEASE_AND_NIL(_touchProcessor);
    SP_RELEASE_AND_NIL(_support);
    SP_RELEASE_AND_NIL(_onRootCreated);
    SP_RELEASE_AND_NIL(_statsDisplay);
    SP_RELEASE_AND_NIL(_programs);
    SP_RELEASE_AND_NIL(_textureLoader);

    [super dealloc];
}

- (void)setup
{
    _contentScaleFactor = 1.0f;
    _stage = [[SPStage alloc] init];
    _juggler = [[SPJuggler alloc] init];
    _touchProcessor = [[SPTouchProcessor alloc] initWithRoot:_stage];
    _programs = [[NSMutableDictionary alloc] init];
    _support = [[SPRenderSupport alloc] init];

    [self initializeContext];

    [SPContext setCurrentContext:_context];
    [Sparrow setCurrentController:self];
}

- (void)createRoot
{
    if (!_root)
    {
        _root = [[_rootClass alloc] init];

        if ([_root isKindOfClass:[SPStage class]])
            [NSException raise:SP_EXC_INVALID_OPERATION
                        format:@"Root extends 'SPStage' but is expected to extend 'SPSprite' "
             @"instead (different to Sparrow 1.x)"];
        else
        {
            [_stage addChild:_root atIndex:0];

            if (_onRootCreated)
            {
                _onRootCreated(_root);
                _onRootCreated = nil;
            }
        }
    }
}

- (void)readjustStageSize
{
    CGSize viewSize = self.view.bounds.size;
    _stage.width  = viewSize.width / _contentScaleFactor;
    _stage.height = viewSize.height / _contentScaleFactor;
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

- (void)initializeContext
{
    // override in subclass
}

#pragma mark - GLKViewDelegate

- (void)renderInRect:(CGRect)rect
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
        [_support nextFrame];

        glDisable(GL_CULL_FACE);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);

        [_stage render:_support];
        [_support finishQuadBatch];

        if (_statsDisplay)
            _statsDisplay.numDrawCalls = _support.numDrawCalls - 2; // stats display requires 2 itself

        #if DEBUG
        [SPRenderSupport checkForOpenGLError];
        #endif
    }
}

- (void)advanceTime:(double)passedTime
{
    @autoreleasepool
    {
        [Sparrow setCurrentController:self];
        [_stage advanceTime:passedTime];
        [_juggler advanceTime:passedTime];
    }
}

- (NSInteger)backBufferWidth
{
    return 0;
}

- (NSInteger)backBufferHeight
{
    return 0;
}

#pragma mark - Program registration

- (void)registerProgram:(SPProgram*)program name:(NSString*)name
{
    _programs[name] = program;
}

- (void)unregisterProgram:(NSString*)name
{
    [_programs removeObjectForKey:name];
}

- (SPProgram*)programByName:(NSString*)name
{
    return _programs[name];
}

@end
