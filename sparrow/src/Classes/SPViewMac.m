//
//  SPGLViewMac.m
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//

#import "SPContext.h"
#import "SPViewMac.h"
#import "SPMacros.h"

@implementation SPViewMac
{
    id<SPViewMacDelegate> _delegate;
}

@synthesize delegate = _delegate;

- (void)dealloc
{
	[super dealloc];
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];

	// The reshape function may have changed the thread to which our OpenGL
	// context is attached before prepareOpenGL and initGL are called.  So call
	// makeCurrentContext to ensure that our OpenGL context current to this
	// thread (i.e. makeCurrentContext directs all OpenGL calls on this thread
	// to [self openGLContext])
	[self.openGLContext makeCurrentContext];

	// Synchronize buffer swaps with vertical refresh rate
	GLint swapInt = 1;
	[self.openGLContext setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

	// Register to be notified when the window closes so we can stop the displaylink
//	[[NSNotificationCenter defaultCenter] addObserver:self
//											 selector:@selector(windowWillClose:)
//												 name:NSWindowWillCloseNotification
//											   object:[self window]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(surfaceNeedsUpdate:)
                                                 name:NSViewGlobalFrameDidChangeNotification
                                               object:self];
}

- (void)display
{
	[self.openGLContext makeCurrentContext];

	// We draw on a secondary thread through the display link
	// When resizing the view, -reshape is called automatically on the main
	// thread. Add a mutex around to avoid the threads accessing the context
	// simultaneously when resizing
	CGLLockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);

    [_delegate renderInRect:self.frame];

	CGLFlushDrawable((CGLContextObj)[[self openGLContext] CGLContextObj]);
	CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
}

#pragma mark properties

- (SPContext*)openGLContext
{
    return (SPContext*)[super openGLContext];
}

- (void)setOpenGLContext:(SPContext*)openGLContext
{
    if (![openGLContext isKindOfClass:[SPContext class]])
        [NSException raise:SP_EXC_INVALID_OPERATION format:@"OpenGL context must be a SPContext."];

    [super setOpenGLContext:openGLContext];
}

#pragma mark overrides

- (void)renewGState
{
	// Called whenever graphics state updated (such as window resize)

	// OpenGL rendering is not synchronous with other rendering on the OSX.
	// Therefore, call disableScreenUpdatesUntilFlush so the window server
	// doesn't render non-OpenGL content in the window asynchronously from
	// OpenGL content, which could cause flickering.  (non-OpenGL content
	// includes the title bar and drawing done by the app with other APIs)
	[[self window] disableScreenUpdatesUntilFlush];

	[super renewGState];
}

- (void)drawRect:(NSRect)theRect
{
	// Called during resize operations
	// Avoid flickering during resize by drawiing
	[self display];
}

- (void)reshape
{
	[super reshape];

	// We draw on a secondary thread through the display link. However, when
	// resizing the view, -drawRect is called on the main thread.
	// Add a mutex around to avoid the threads accessing the context
	// simultaneously when resizing.
	CGLLockContext((CGLContextObj)[self.openGLContext CGLContextObj]);

	// Get the view size in Points
	NSRect viewRectPoints = [self bounds];

#if SUPPORT_RETINA_RESOLUTION

    // Rendering at retina resolutions will reduce aliasing, but at the potential
    // cost of framerate and battery life due to the GPU needing to render more
    // pixels.

    // Any calculations the renderer does which use pixel dimentions, must be
    // in "retina" space.  [NSView convertRectToBacking] converts point sizes
    // to pixel sizes.  Thus the renderer gets the size in pixels, not points,
    // so that it can set it's viewport and perform and other pixel based
    // calculations appropriately.
    // viewRectPixels will be larger (2x) than viewRectPoints for retina displays.
    // viewRectPixels will be the same as viewRectPoints for non-retina displays
    NSRect viewRectPixels = [self convertRectToBacking:viewRectPoints];

#else //if !SUPPORT_RETINA_RESOLUTION

    // App will typically render faster and use less power rendering at
    // non-retina resolutions since the GPU needs to render less pixels.  There
    // is the cost of more aliasing, but it will be no-worse than on a Mac
    // without a retina display.

    // Points:Pixels is always 1:1 when not supporting retina resolutions
    NSRect viewRectPixels = viewRectPoints;

#endif // !SUPPORT_RETINA_RESOLUTION

	// Set the new dimensions in our renderer
    [_delegate reshapeWithRect:viewRectPixels];

	CGLUnlockContext((CGLContextObj)[self.openGLContext CGLContextObj]);
}

- (void)update
{
    [super update];

    [self reshape];
    [self display];
}

-(BOOL) acceptsFirstResponder
{
	return YES;
}

-(BOOL) becomeFirstResponder
{
	return YES;
}

#pragma mark notifications

- (void)surfaceNeedsUpdate:(NSNotification*)notification
{
    [self reshape];
    [self display];
}

@end
