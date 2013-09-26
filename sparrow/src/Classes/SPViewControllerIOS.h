//
//  SPViewController.h
//  Sparrow
//
//  Created by Daniel Sperl on 26.01.13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPViewController.h"

/** ------------------------------------------------------------------------------------------------
 
 An SPViewController controls and displays a Sparrow display tree. It represents the main
 link between UIKit and Sparrow.
 
 The class acts just like a conventional view controller of UIKit. It extends `GLKViewController`,
 setting up a `GLKView` object that Sparrow can render into.
 
 To initialize the Sparrow display tree, call the 'startWithRoot:' method (or a variant)
 with the class that should act as the root object of your game. As soon as OpenGL is set up,
 an instance of that class will be created and your game will start. In this sample, `Game` is
 a subclass of `SPSprite` that sets up the display tree of your app:
 
	[viewController startWithRoot:[Game class]];
 
 If you need to pass certain information to your game, you can make use of the `onRootCreated` 
 callback:
 
	viewController.onRootCreated = ^(Game *game)
	{
	    // access your game instance here
	};
 
 **Resolution Handling**
 
 Just like in other UIKit apps, the size of the visible area (in Sparrow, the stage size) is given
 in points. Those values will always equal the non-retina resolution of the current device.
 
 Per default, Sparrow is started with support for retina displays, which means that it will 
 automatically use the optimal available screen resolution and will load retina versions of your
 textures (files with the `@2x` prefix) on a suitable device.
 
 To simplify the creation of universal apps, Sparrow can double the size of all objects on the iPad,
 effectively turning it into the retina version of an (imaginary) phone with a resolution of
 `384x512` pixels. That will be your stage size then, and iPads 1+2 will load `@2x` versions of
 your textures. Retina iPads will use a new suffix instead: `@4x`.
 
 If you want this to happen (again: only useful for universal apps), enable the `doubleOnPad`
 parameter of the `start:` method. Otherwise, Sparrow will work just like other UIKit apps, using
 a stage size of `768x1024` on the iPad.
 
 **Render Settings**
 
 Some of the basic render settings are controlled by the base class, `GLKViewController`:
 
 * Set the desired framerate through the `preferredFramesPerSecond` property
 * Pause or restart Sparrow through the `paused` property

 **Accessing the current controller**
 
 As a convenience, you can access the view controller through a static method on the `Sparrow`
 class:
 
	SPViewController* controller = Sparrow.currentController;
 
 Since the view controller contains pointers to the stage, root, and juggler, you can
 easily access those objects that way.
 
------------------------------------------------------------------------------------------------- */

@interface SPViewControllerIOS : SPViewController

/// -------------
/// @name Startup
/// -------------

/// Sets up Sparrow by instantiating the given class, which has to be a display object.
/// High resolutions are enabled, iPad content will keep its size (no doubling).
- (void)startWithRoot:(Class)rootClass;

/// Sets up Sparrow by instantiating the given class, which has to be a display object.
/// iPad content will keep its size (no doubling).
- (void)startWithRoot:(Class)rootClass supportHighResolutions:(BOOL)hd;

/// Sets up Sparrow by instantiating the given class, which has to be a display object. Optionally,
/// you can double the size of iPad content, which will give you a stage size of `384x512`. That
/// simplifies the creation of universal apps (see class documentation).
- (void)startWithRoot:(Class)rootClass supportHighResolutions:(BOOL)hd doubleOnPad:(BOOL)doubleOnPad;

/// ----------------
/// @name Properties
/// ----------------

/// Indicates if multitouch input is enabled.
@property (nonatomic, assign) BOOL multitouchEnabled;

/// Indicates if retina display support is enabled.
@property (nonatomic, readonly) BOOL supportHighResolutions;

/// Indicates if display list contents will doubled on iPad devices (see class documentation).
@property (nonatomic, readonly) BOOL doubleOnPad;

@end
