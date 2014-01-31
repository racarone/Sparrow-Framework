//
//  SPContext.h
//  Sparrow
//
//  Created by Robert Carone on 1/11/14.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>

@class SPRectangle;
@class SPTexture;

/** ------------------------------------------------------------------------------------------------
 
 An SPContext object manages the state information, commands, and resources needed to draw using
 OpenGL. All OpenGL commands are executed in relation to a context. SPContext wraps the native 
 context and provides additional functionality.

------------------------------------------------------------------------------------------------- */

@interface SPContext : NSObject

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes and returns a rendering context with the specified sharegroup.
- (instancetype)initWithSharegroup:(id)sharegroup;

/// -------------
/// @name Methods
/// -------------

/// Sets the back rendering buffer as the render target.
- (void)renderToBackBuffer;

/// Displays a renderbuffer’s contents on screen.
- (void)presentBufferForDisplay;

/// Makes the specified context the current rendering context for the calling thread.
+ (BOOL)setCurrentContext:(SPContext *)context;

/// Returns the current rendering context for the calling thread.
+ (SPContext *)currentContext;

/// Returns YES if the current devices supports the extension.
+ (BOOL)deviceSupportsOpenGLExtension:(NSString *)extensionName;

/// ----------------
/// @name Properties
/// ----------------

/// The receiver’s sharegroup object.
@property (atomic, readonly) id sharegroup;

/// The receiver’s native context object.
@property (atomic, readonly) id nativeContext;

/// The current OpenGL viewport rectangle.
@property (nonatomic, assign) SPRectangle *viewport;

/// The current OpenGL scissor rectangle.
@property (nonatomic, assign) SPRectangle *scissorBox;

/// The specified texture as the rendering target or nil if rendering to the default framebuffer.
@property (nonatomic, retain) SPTexture *renderTarget;

@end
