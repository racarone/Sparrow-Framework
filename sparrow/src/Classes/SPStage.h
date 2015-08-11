//
//  SPStage.h
//  Sparrow
//
//  Created by Daniel Sperl on 15.03.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <Sparrow/SPDisplayObjectContainer.h>

NS_ASSUME_NONNULL_BEGIN

@class SPJuggler;
@class UIImage;

/** ------------------------------------------------------------------------------------------------

 An SPStage is the root of the display tree. It represents the rendering area of the application.
 
 Sparrow will create the stage for you. The root object of your game will be the first child of
 the stage. You can access `root` and `stage` from any display object using the respective 
 properties. 
 
 The stage's `width` and `height` values define the coordinate system of your game. The color
 of the stage defines the background color of your game.
 
------------------------------------------------------------------------------------------------- */

@interface SPStage : SPDisplayObjectContainer

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes a stage with a certain size in points.
- (instancetype)initWithWidth:(float)width height:(float)height;

/// -------------
/// @name Methods
/// -------------

/// Returns the position of the camera within the local coordinate system of a certain
/// display object. If you do not pass a space, the method returns the global position.
/// To change the position of the camera, you can modify the properties 'fieldOfView',
/// 'focalDistance' and 'projectionOffset'.
- (SPVector3D *)cameraPositionInSpace:(nullable SPDisplayObject *)targetSpace;


/// Draws the complete stage into an UIImage object, empty areas will appear transparent.
- (UIImage *)drawToImage;

/// Draws the complete stage into an UIImage object.
///
/// @param transparent  If enabled, empty areas will appear transparent; otherwise, they
///                     will be filled with the stage color.
- (UIImage *)drawToImage:(BOOL)transparent;

/// ----------------
/// @name Properties
/// ----------------

/// The background color of the stage. Default: black.
@property (nonatomic, assign) uint color;

/// The height of the stage's coordinate system.
@property (nonatomic, assign) float width;

/// The width of the stage's coordinate system.
@property (nonatomic, assign) float height;

/// The distance between the stage and the camera. Changing this value will update the
/// field of view accordingly.
@property (nonatomic, assign) float focalLength;

/// Specifies an angle (radian, between zero and PI) for the field of view. This value determines
/// how strong the perspective transformation and distortion apply to a Sprite3D object.
///
/// A value close to zero will look similar to an orthographic projection; a value close to PI
/// results in a fisheye lens effect. If the field of view is set to 0 or PI, nothing is seen on
/// the screen.
///
/// @default 1.0
@property (nonatomic, assign) float fieldOfView;

/// A vector that moves the camera away from its default position in the center of the
/// stage. Use this property to change the center of projection, i.e. the vanishing
/// point for 3D display objects. CAUTION: not a copy, but the actual object!
@property (nonatomic, assign) SPPoint *projectionOffset;

/// The global position of the camera. This property can only be used to find out the current
/// position, but not to modify it. For that, use the 'projectionOffset', 'fieldOfView' and
/// 'focalLength' properties. If you need the camera position in a certain coordinate space, use
/// 'cameraPositionInSpace' instead. 
@property (nonatomic, readonly) SPVector3D *cameraPosition;

@end

NS_ASSUME_NONNULL_END
