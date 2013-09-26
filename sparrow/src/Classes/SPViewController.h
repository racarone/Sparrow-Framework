//
//  SPController.h
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

#import "SPMacros.h"

#if SP_TARGET_IPHONE
    #define SP_VIEW_CONTROLLER GLKViewController
#else
    #define SP_VIEW_CONTROLLER NSViewController
#endif

@class SPContext;
@class SPDisplayObject;
@class SPFramebuffer;
@class SPJuggler;
@class SPProgram;
@class SPRenderSupport;
@class SPStage;
@class SPTouchProcessor;

typedef void (^SPRootCreatedBlock)(id root);

@interface SPViewController : SP_VIEW_CONTROLLER

/// ------------------------
/// @name Program Management
/// ------------------------

/// Registers a shader program under a certain name.
- (void)registerProgram:(SPProgram*)program name:(NSString*)name;

/// Deletes the vertex- and fragment-programs of a certain name.
- (void)unregisterProgram:(NSString*)name;

/// Returns the shader program registered under a certain name.
- (SPProgram*)programByName:(NSString*)name;

/// ----------------
/// @name Properties
/// ----------------

/// The instance of the root class provided in `start:`method.
@property (nonatomic, readonly) SPDisplayObject* root;

/// The stage object, i.e. the root of the display tree.
@property (nonatomic, readonly) SPStage* stage;

/// The default juggler of this instance. It is automatically advanced once per frame.
@property (nonatomic, readonly) SPJuggler* juggler;

/// The OpenGL context used for rendering.
@property (nonatomic, readonly) SPContext* context;

/// Returns the actual width (in pixels) of the back buffer. This can differ from the
/// width of the viewPort rectangle if it is partly outside the default framebuffer.
@property (nonatomic, readonly) NSInteger backBufferWidth;

/// Returns the actual height (in pixels) of the back buffer. This can differ from the
/// height of the viewPort rectangle if it is partly outside the default framebuffer.
@property (nonatomic, readonly) NSInteger backBufferHeight;

/// Indicates if a small statistics box (with FPS and draw count) is displayed.
@property (nonatomic, assign) BOOL showStats;

/// Indicates if retina display support is enabled.
@property (nonatomic, readonly) BOOL supportHighResolutions;

/// The current content scale factor, i.e. the ratio between display resolution and stage size.
@property (nonatomic, readonly) float contentScaleFactor;

/// A callback block that will be executed when the root object has been created.
@property (nonatomic, copy) SPRootCreatedBlock onRootCreated;

/// A texture loader object that is initialized with the sharegroup of the current OpenGL context.
@property (nonatomic, readonly) GLKTextureLoader* textureLoader;

@end
