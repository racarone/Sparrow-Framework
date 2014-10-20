//
//  SPContext.h
//  Sparrow
//
//  Created by Robert Carone on 1/11/14.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <UIKit/UIKit.h>
#import <Sparrow/SPEventDispatcher.h>

@class SPRectangle;
@class SPTexture;
@class SPView;

/** ------------------------------------------------------------------------------------------------
 
 An SPContext object manages the state information, commands, and resources needed to draw using
 OpenGL. All OpenGL commands are executed in relation to a context. SPContext wraps the native 
 context and provides additional functionality.

------------------------------------------------------------------------------------------------- */

@interface SPContext : SPEventDispatcher

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes and returns a rendering context with the specified share context.
- (instancetype)initWithShareContext:(SPContext *)shareContext;

/// Initializes and returns a rendering context.
- (instancetype)init;

/// Returns the global context used for sharing.
+ (instancetype)globalShareContext;

/// -------------
/// @name Methods
/// -------------

/// Sets the back rendering buffer as the render target.
- (void)renderToBackBuffer;

/// Displays the back rendering buffer.
- (void)present;

/// Clears the contexts of the current render target.
- (void)clear;

/// Clears the contexts of the current render target with a specified color.
- (void)clearWithColor:(uint)color;

/// Clears the contexts of the current render target with a specified color and alpha.
- (void)clearWithColor:(uint)color alpha:(float)alpha;

/// Makes the receiver the current current rendering context.
- (BOOL)makeCurrentContext;

/// Makes the specified context the current rendering context for the calling thread.
+ (BOOL)setCurrentContext:(SPContext *)context;

/// Returns the current rendering context for the calling thread.
+ (SPContext *)currentContext;

/// Returns YES if the current devices supports the extension.
+ (BOOL)deviceSupportsOpenGLExtension:(NSString *)extensionName;

/// ----------------
/// @name Properties
/// ----------------

/// The receiver’s native context object.
@property (atomic, readonly) EAGLContext *nativeContext;

/// The current OpenGL viewport rectangle in pixels.
@property (nonatomic, assign) SPRectangle *viewport;

/// The current OpenGL scissor rectangle in pixels.
@property (nonatomic, assign) SPRectangle *scissorBox;

/// The specified texture as the rendering target or nil if rendering to the default framebuffer.
@property (nonatomic, retain) SPTexture *renderTarget;

@end
