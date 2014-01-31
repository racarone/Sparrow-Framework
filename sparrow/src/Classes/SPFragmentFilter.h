//
//  SPFragmentFilter.h
//  Sparrow
//
//  Created by Robert Carone on 9/16/13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>

@class SPDisplayObject;
@class SPMatrix;
@class SPRenderSupport;
@class SPTexture;

// Filter Mode
typedef NS_ENUM(uint, SPFragmentFilterMode)
{
    SPFragmentFilterModeBelow,
    SPFragmentFilterModeReplace,
    SPFragmentFilterModeAbove
};

/** ------------------------------------------------------------------------------------------------

 The SPFragmentFilter class is the base class for all filter effects in Sparrow.

 All other filters of this package extend this class. You can attach them to any display object
 through the 'filter' property.

 A fragment filter works in the following way:
    * The object that is filtered is rendered into a texture (in stage coordinates).
    * That texture is passed to the first filter pass.
    * Each pass processes the texture using a fragment shader (and optionally a vertex shader) to
        achieve a certain effect.
    * The output of each pass is used as the input for the next pass; if it's the final pass, it will
        be rendered directly to the back buffer.

 All of this is set up by the abstract SPFragmentFilter class. Concrete subclasses just need to 
 override the protected methods 'createPrograms', 'activateWithPass' and (optionally) 
 'deactivateWithPass' to create and execute its custom shader code. Each filter can be configured to 
 either replace the original object, or be drawn below or above it. This can be done through the 
 'mode' property, which accepts one of the enums defined in the 'SPFragmentFilterMode' enum.

 Beware that each filter should be used only on one object at a time. Otherwise, it will get slower
 and require more resources; and caching will lead to undefined results.

------------------------------------------------------------------------------------------------- */

@interface SPFragmentFilter : NSObject

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes a fragment filter with the specified number of passes and resolution.
/// This initializer must only be called by the initializer of a subclass.
/// _Designated Initializer_.
- (instancetype)initWithNumPasses:(int)numPasses resolution:(float)resolution;

/// Initializes a fragment filter with the specified number of passes and a resolution of 1.0f.
/// This initializer must only be called by the initializer of a subclass.
- (instancetype)initWithNumPasses:(int)numPasses;

/// Initializes a fragment filter with 1 pass and a resolution of 1.0f.
/// This initializer must only be called by the initializer of a subclass.
- (instancetype)init;

/// -------------
/// @name Methods
/// -------------

/// Caches the filter output into a SPTexture. An uncached filter is rendered in every frame; a
/// cached filter only once. However, if the filtered object or the filter settings change, it has
/// to be updated manually; to do that, call "cache" again.
- (void)cache;

/// Clears the cached output of the filter. After calling this method, the filter will be executed
/// once per frame again.
- (void)clearCache;

/// Applies the filter on a certain display object, rendering the output into the current render
/// target. This method is called automatically by Sparrow's rendering system for the object the
/// filter is attached to.
- (void)renderObject:(SPDisplayObject *)object support:(SPRenderSupport *)support;

/// ----------------
/// @name Properties
/// ----------------

/// Indicates if the filter is cached (via the "cache" method).
@property (nonatomic, readonly) BOOL cached;

/// The resolution of the filter texture. "1" means stage resolution, "0.5" half the stage
/// resolution. A lower resolution saves memory and execution time(depending on the GPU), but
/// results in a lower output quality. Values greater than 1 are allowed; such values might make
/// sense for a cached filter when it is scaled up. @default 1
@property (nonatomic, assign) float resolution;

/// The filter mode, which is one of the constants defined in the 'SPFragmentFilterMode' enum.
/// (default: SPFragmentFilterModeReplace)
@property (nonatomic, assign) SPFragmentFilterMode mode;

/// Use the x-offset to move the filter output to the right or left.
@property (nonatomic, assign) float offsetX;

/// Use the y-offset to move the filter output to the top or bottom.
@property (nonatomic, assign) float offsetY;

@end


/** SPFragmentFilter subclass category. */
@interface SPFragmentFilter (Subclasses)

/// -------------
/// @name Methods
/// -------------

/// Subclasses must override this method and use it to create their fragment and vertex shaders.
- (void)createPrograms;

/// Subclasses must override this method and use it to activate their shader program.
/// The 'activate' call directly precedes the call to 'glDrawElements'.
- (void)activateWithPass:(int)pass texture:(SPTexture *)texture mvpMatrix:(SPMatrix *)matrix;

/// This method is called directly after 'glDrawElements'.
/// If you need to clean up any resources, you can do so in this method.
- (void)deactivateWithPass:(int)pass texture:(SPTexture *)texture;

/// The standard vertex shader code. It will be used automatically if you don't create a custom
/// vertex shader yourself.
+ (NSString *)standardVertexShader;

/// The standard fragment shader code. It just forwards the texture color to the output.
+ (NSString *)standardFragmentShader;

/// ----------------
/// @name Properties
/// ----------------

/// The x-margin will extend the size of the filter texture along the x-axis.
/// Useful when the filter will "grow" the rendered object.
@property (nonatomic, assign) float marginX;

/// The y-margin will extend the size of the filter texture along the y-axis.
/// Useful when the filter will "grow" the rendered object.
@property (nonatomic, assign) float marginY;

/// The number of passes the filter is applied. The "activate" and "deactivate" methods will be
/// called that often.
@property (nonatomic, assign) int numPasses;

/// The ID of the vertex buffer attribute that stores the vertex position.
@property (nonatomic, assign) int vertexPosID;

/// The ID of the vertex buffer attribute that stores the SPTexture coordinates.
@property (nonatomic, assign) int texCoordsID;

@end
