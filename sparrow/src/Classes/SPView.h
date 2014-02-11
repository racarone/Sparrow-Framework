//
//  SPView.h
//  Sparrow
//
//  Created by Robert Carone on 2/5/14.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <UIKit/UIKit.h>
#import <Sparrow/SPMacros.h>

@protocol SPViewDelegate;
@class SPContext;

@interface SPView : UIView

/// ------------------
/// @name Initializers
/// ------------------

/// Initializes a new view with an OpenGL context used to store the framebuffer object.
- (id)initWithFrame:(CGRect)frame context:(SPContext *)context;

/// -------------
/// @name Methods
/// -------------

/// Renders a frame, will call "drawRect:" if no delegate has been set.
- (void)render;

/// Binds the context and drawable.
- (void)bindDrawable;

/// Deletes the backing framebuffer, ususally called when an application is backgrounded.
- (void)deleteDrawable;

/// ----------------
/// @name Properties
/// ----------------

/// If a delegate is provided, it is called instead of calling a drawRect: method whenever the
/// view’s contents need to be drawn.
@property (nonatomic, assign) id<SPViewDelegate> delegate;

/// The OpenGL context used when drawing the view’s contents. Never change the context from inside
/// your drawing method.
@property (nonatomic, strong) SPContext *context;

/// Controls whether the view responds to setNeedsDisplay. When the view has been marked for
/// display, the draw method is called during the next drawing cycle.
@property (nonatomic, assign) BOOL enableSetNeedsDisplay;

/// Indicates if the view is currently rendering a frame.
@property (nonatomic, readonly) BOOL rendering;

/// The width, in pixels, of the underlying framebuffer object.
@property (nonatomic, readonly) int drawableWidth;

/// The height, in pixels, of the underlying framebuffer object.
@property (nonatomic, readonly) int drawableHeight;

@end


@protocol SPViewDelegate <NSObject>
@required

/// Delegate method used to render OpenGL content.
- (void)renderRect:(CGRect)rect view:(SPView *)view;

@end
