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

@class SPContext;
@class SPViewController;

/** A view to render Sparrow's content to. */

@interface SPView : UIView

/// Configure the back buffer based on the view's properties.
- (void)configureBackBuffer;

/// The parent view controller of this view.
@property (nonatomic, weak) SPViewController *viewController;

/// The OpenGL context used for rendering.
@property (nonatomic, strong) SPContext *context;

/// The antialiasing level. 0 - no antialasing, 16 - maximum antialiasing. (default: 0).
@property (nonatomic, assign) int antiAliasing;

/// Indicates if the depth and stencil renderbuffers are enabled.
@property (nonatomic, assign) BOOL enableDepthAndStencil;

/// Indicates if retina display support is enabled.
@property (nonatomic, assign) BOOL supportHighResolutions;

@end
