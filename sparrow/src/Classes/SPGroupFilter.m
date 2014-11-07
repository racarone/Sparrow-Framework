//
//  SPFilterStack.m
//  Sparrow
//
//  Created by Robert Carone on 11/6/14.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPBaseEffect.h>
#import <Sparrow/SPDisplayObject.h>
#import <Sparrow/SPGroupFilter.h>
#import <Sparrow/SPGLTexture.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPRenderSupport.h>
#import <Sparrow/SPStage.h>

@interface SPFragmentFilter (Internal)

- (void)calcBoundsWithObject:(SPDisplayObject *)object stage:(SPStage *)stage scale:(float)scale
                   intersect:(BOOL)intersectWithStage intoBounds:(out SPRectangle **)bounds;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPGroupFilter
{
    NSArray *_filters;

    SPBaseEffect *_baseEffect;
    SPTexture *_originalTexture;
    BOOL _currentSubFilterNeedsOriginalTexture;

    SPFragmentFilter *_currentSubFilter;
    SPDisplayObject *_currentObject;
    SPRenderSupport *_currentSupport;

    SPRectangle *_currentBounds;
    float _currentScale;

    int _subFilterIndex;
    int _currentSubPass;
}

#pragma mark Initialization

- (instancetype)initWithFilters:(NSArray *)filters
{
    if (self = [super init])
    {
        self.filters = filters;
    }

    return self;
}

+ (instancetype)groupFilterWithFilters:(NSArray *)filters
{
    return [[[self alloc] initWithFilters:filters] autorelease];
}

#pragma mark Properties

- (void)setFilters:(NSArray *)filters
{
    SP_RELEASE_AND_COPY(_filters, filters);
}

#pragma mark SPFragmentFilter (Subclasses)

- (void)createEffects
{
    _baseEffect = [[SPBaseEffect alloc] init];
    _baseEffect.useTinting = NO;
}

- (SPEffect *)effectForPass:(int)pass
{
    if (_currentSubPass >= _currentSubFilter.numPasses)
    {
        // next sub filter
        _currentSubFilter = _filters[++_subFilterIndex];
        _currentSubPass = 0;
        _currentSubFilterNeedsOriginalTexture = _currentSubFilter.mode == SPFragmentFilterModeBelow;
    }

    return [_currentSubFilter effectForPass:_currentSubPass];
}

- (void)activateWithPass:(int)pass texture:(SPTexture *)texture
{
    if (_currentSubFilterNeedsOriginalTexture || (_currentSubPass == 0 && _currentSubFilter.mode == SPFragmentFilterModeAbove))
    {
        SPMatrix *mvpMatrix = _currentSupport.mvpMatrix;
        [self setupBaseEffectWithTexture:texture matrix:mvpMatrix];

        // draw the original object
        if (_currentSubFilter.mode == SPFragmentFilterModeAbove)
            [self draw];

        // save the original object to a texture
        if (_currentSubFilterNeedsOriginalTexture)
            [self drawIntoOriginalTexture];

        // restore the current effect for the sub filter
        [self restoreEffectForPass:pass texture:texture matrix:mvpMatrix];
    }

    [_currentSubFilter activateWithPass:_currentSubPass texture:texture];
}

- (void)deactivateWithPass:(int)pass texture:(SPTexture *)texture
{
    [_currentSubFilter deactivateWithPass:_currentSubPass texture:texture];

    ++_currentSubPass;

    if (_currentSubPass == _currentSubFilter.numPasses &&
        _currentSubFilter.mode == SPFragmentFilterModeBelow)
    {
        // render the original object on top of the current sub filter
        SPMatrix *mvpMatrix = _currentSupport.mvpMatrix;
        [self setupBaseEffectWithTexture:_originalTexture matrix:mvpMatrix];
        [self draw];
    }
}

#pragma mark SPFragmentFilter

- (void)renderObject:(SPDisplayObject *)object support:(SPRenderSupport *)support
{
    self.numPasses = 0;
    for (SPFragmentFilter *filter in _filters)
        self.numPasses += filter.numPasses;

    if (self.numPasses == 0)
    {
        [object render:support];
        return;
    }

    _currentObject = object;
    _currentSupport = support;

    [self reset];
    [super renderObject:object support:support];

    _currentObject = nil;
    _currentSupport = nil;
    _currentBounds = nil;
    _currentSubFilterNeedsOriginalTexture = NO;
}

- (void)calcBoundsWithObject:(SPDisplayObject *)object stage:(SPStage *)stage scale:(float)scale
                   intersect:(BOOL)intersectWithStage intoBounds:(out SPRectangle **)bounds
{
    [super calcBoundsWithObject:object stage:stage scale:scale intersect:intersectWithStage
                     intoBounds:bounds];

    for (SPFragmentFilter *filter in _filters)
    {
        SPRectangle *subBounds = nil;
        [filter calcBoundsWithObject:object stage:stage scale:scale intersect:intersectWithStage
                          intoBounds:&subBounds];

        *bounds = [*bounds uniteWithRectangle:subBounds];
    }

    _currentBounds = *bounds;
    _currentScale = scale;
}

#pragma mark Private

- (void)reset
{
    _subFilterIndex = 0;
    _currentSubPass = 0;
    _currentSubFilter = _filters[_subFilterIndex];
    _currentSubFilterNeedsOriginalTexture = _currentSubFilter.mode == SPFragmentFilterModeBelow;
}

- (void)setupBaseEffectWithTexture:(SPTexture *)texture matrix:(SPMatrix *)matrix
{
    _baseEffect.mainTexture = texture;
    _baseEffect.mvpMatrix = [matrix convertToGLKMatrix4];
    [_baseEffect prepareToDraw];
}

- (void)restoreEffectForPass:(int)pass texture:(SPTexture *)texture matrix:(SPMatrix *)matrix
{
    SPEffect *effect = [self effectForPass:pass];
    effect.mainTexture = texture;
    effect.mvpMatrix = [matrix convertToGLKMatrix4];
}

- (void)draw
{
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, 0);
}

- (void)drawIntoOriginalTexture
{
    [self updateOriginalTexureWithWidth:_currentBounds.width height:_currentBounds.height scale:_currentScale];

    SPTexture *previousTexture = _currentSupport.renderTarget;
    [_currentSupport setRenderTarget:_originalTexture];
    [_currentSupport clear];

    [self draw];

    _currentSupport.renderTarget = previousTexture;
    _currentSubFilterNeedsOriginalTexture = NO;
}

- (void)updateOriginalTexureWithWidth:(int)width height:(int)height scale:(float)scale
{
    BOOL needsUpdate = _originalTexture.width  != width ||
                       _originalTexture.height != height;

    if (needsUpdate)
    {
        SPTextureProperties properties = {
            .format = SPTextureFormatRGBA,
            .scale  = scale,
            .width  = width  * scale,
            .height = height * scale,
            .numMipmaps = 0,
            .generateMipmaps = NO,
            .premultipliedAlpha = YES
        };

        SP_RELEASE_AND_RETAIN(_originalTexture, [[[SPGLTexture alloc] initWithData:NULL properties:properties] autorelease]);
    }
}

@end
