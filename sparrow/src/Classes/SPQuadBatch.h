//
//  SPQuadBatch.h
//  Sparrow
//
//  Created by Daniel Sperl on 01.03.13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import <Sparrow/SPDisplayObject.h>

@class SPEffect;
@class SPImage;
@class SPQuad;
@class SPTexture;
@class SPVertexData;

/** ------------------------------------------------------------------------------------------------
 
 Optimizes rendering of a number of quads with an identical state.
 
 The majority of all rendered objects in Sparrow are quads. In fact, all the default
 leaf nodes of Sparrow are quads (the `SPImage` and `SPQuad` classes). The rendering of those
 quads can be accelerated by a big factor if all quads with an identical state are sent
 to the GPU in just one call. That's what the `SPQuadBatch` class can do.
 
 The `flatten` method of the `SPSprite` class uses this class internally to optimize its
 rendering performance. In most situations, it is recommended to stick with flattened
 sprites, because they are easier to use. Sometimes, however, it makes sense
 to use the SPQuadBatch class directly: e.g. you can add one quad multiple times to
 a quad batch, whereas you can only add it once to a sprite. Furthermore, this class
 does not dispatch `ADDED` or `ADDED_TO_STAGE` events when a quad
 is added, which makes it more lightweight.
 
 One QuadBatch object is bound to a specific render state. The first object you add to a
 batch will decide on the QuadBatch's state, that is: its texture, its settings for
 smoothing and repetition, and if it's tinted (colored vertices and/or transparency).
 When you reset the batch, it will accept a new state on the next added quad.
 
------------------------------------------------------------------------------------------------- */
@interface SPQuadBatch : SPDisplayObject
{
    SPVertexData *_vertexData;
}

/// --------------------
/// @name Initialization
/// --------------------

/// Initialize a QuadBatch with a certain capacity. The batch will grow dynamically if it exceeds
/// this value. _Designated Initializer_.
- (instancetype)initWithCapacity:(int)capacity;

/// Initialize a QuadBatch with a capacity of 16 quads.
- (instancetype)init;

/// Create a new, empty quad batch.
+ (instancetype)quadBatch;

/// -------------
/// @name Methods
/// -------------

/// Resets the batch. The vertex- and index-buffers keep their size, so that they can be reused.
- (void)reset;

/// Adds a quad or image. Make sure you only add quads with an equal state.
- (void)addQuad:(SPQuad *)quad;

/// Adds a quad or image using a custom alpha value (ignoring the quad's original alpha).
/// Make sure you only add quads with an equal state.
- (void)addQuad:(SPQuad *)quad alpha:(float)alpha;

/// Adds a quad or image to the batch, using custom alpha and blend mode values (ignoring the
/// quad's original values). Make sure you only add quads with an equal state.
- (void)addQuad:(SPQuad *)quad alpha:(float)alpha blendMode:(uint)blendMode;

/// Adds a quad or image to the batch, using custom alpha and blend mode values (ignoring the
/// quad's original values) and transforming each vertex by a certain transformation matrix.
/// Make sure you only add quads with an equal state.
- (void)addQuad:(SPQuad *)quad alpha:(float)alpha blendMode:(uint)blendMode matrix:(SPMatrix *)matrix;

/// Adds another quad batch to this batch.
- (void)addQuadBatch:(SPQuadBatch *)quadBatch;

/// Adds another quad batch to this batch, using a custom alpha value (ignoring the batch's
/// original alpha).
- (void)addQuadBatch:(SPQuadBatch *)quadBatch alpha:(float)alpha;

/// Adds another quad batch to this batch, using custom alpha and blend mode values (ignoring the
/// batch's original values). Just like the `addQuad:` method, you have to make sure that you only
/// add batches with an equal state.
- (void)addQuadBatch:(SPQuadBatch *)quadBatch alpha:(float)alpha blendMode:(uint)blendMode;

/// Adds another quad batch to this batch, using custom alpha and blend mode values (ignoring the
/// batch's original values) and transforming each vertex by a certain transformation matrix. Just
/// like the `addQuad:` method, you have to make sure that you only add batches with an equal state.
- (void)addQuadBatch:(SPQuadBatch *)quadBatch alpha:(float)alpha blendMode:(uint)blendMode
              matrix:(SPMatrix *)matrix;

/// Indicates if specific quads can be added to the batch without causing a state change.
/// A state change occurs if the quad uses a different effect, base texture, or 'tinted' setting,
/// or if the batch is full (one batch can contain up to 16383 quads).
- (BOOL)isStateChangeWithEffect:(SPEffect *)effect texture:(SPTexture *)texture tinted:(BOOL)tinted
                          alpha:(float)alpha premultipliedAlpha:(BOOL)pma blendMode:(uint)blendMode
                       numQuads:(int)numQuads;

/// ---------------------
/// @name Utility Methods
/// ---------------------

/// Call this method after manually changing the contents of '_vertexData'.
- (void)vertexDataDidChange;

/// Transforms the vertices of a certain quad by the given matrix.
- (void)transformQuadAtIndex:(int)quadID matrix:(SPMatrix *)matrix;

/// Returns the color of one vertex of a specific quad.
- (uint)vertexColorOfQuad:(int)quadID atIndex:(int)vertexID;

/// Updates the color of one vertex of a specific quad.
- (void)setVertexColor:(uint)color ofQuad:(int)quadID atIndex:(int)vertexID;

/// Returns the alpha value of one vertex of a specific quad.
- (float)vertexAlphaOfQuad:(int)quadID atIndex:(int)vertexID;

/// Updates the alpha value of one vertex of a specific quad.
- (void)setVertexAlpha:(float)alpha ofQuad:(int)quadID atIndex:(int)vertexID;

/// Returns the color of the first vertex of a specific quad.
- (uint)vertexColorOfQuad:(int)quadID;

/// Updates the color of a specific quad.
- (void)setVertexColor:(uint)color ofQuad:(int)quadID;

/// Returns the alpha value of the first vertex of a specific quad.
- (float)vertexAlphaOfQuad:(int)quadID;

/// Updates the alpha value of a specific quad.
- (void)setVertexAlpha:(float)alpha ofQuad:(int)quadID;

/// Calculates the bounds of a specific quad.
- (SPRectangle *)boundsOfQuad:(int)quadID;

/// Calculates the bounds of a specific quad transformed by a matrix.
- (SPRectangle *)boundsOfQuad:(int)quadID afterTransformation:(SPMatrix *)matrix;

/// ----------------------
/// @name Custom Rendering
/// ----------------------

/// Renders the batch with custom alpha and blend mode values, as well as a custom mvp matrix.
- (void)renderWithMvpMatrix:(SPMatrix *)matrix alpha:(float)alpha blendMode:(uint)blendMode;

/// Renders the batch with a custom mvp matrix.
- (void)renderWithMvpMatrix:(SPMatrix *)matrix;

/// -----------------
/// @name Compilation
/// -----------------

/// Analyses an object that is made up exclusively of quads (or other containers) and creates an
/// array of `SPQuadBatch` objects representing it. This can be used to render the container very
/// efficiently. The 'flatten'-method of the `SPSprite` class uses this method internally. */
+ (NSMutableArray *)compileObject:(SPDisplayObject *)object;

/// Analyses an object that is made up exclusively of quads (or other containers) and saves the
/// resulting quad batches into the specified an array; batches inside that array are reused.
+ (NSMutableArray *)compileObject:(SPDisplayObject *)object intoArray:(NSMutableArray *)quadBatches;

/// ----------------
/// @name Properties
/// ----------------

/// The number of quads that has been added to the batch.
@property (nonatomic, readonly) int numQuads;

/// Indicates if any vertices have a non-white color or are not fully opaque.
@property (nonatomic, readonly) BOOL tinted;

/// The current texture of the batch, if there is one.
@property (nonatomic, readonly) SPTexture *texture;

/// Indicates if the rgb values are stored premultiplied with the alpha value.
@property (nonatomic, readonly) BOOL premultipliedAlpha;

/// The current effect of the batch, if there is one. Set this manually if you want a custom effect
/// for the entire batch.
@property (nonatomic, strong) SPEffect *effect;

/// Indicates the number of quads for which space is allocated (vertex- and index-buffers).
/// If you add more quads than what fits into the current capacity, the QuadBatch is
/// expanded automatically. However, if you know beforehand how many vertices you need,
/// you can manually set the right capacity with this method.
@property (nonatomic, assign) int capacity;

@end
