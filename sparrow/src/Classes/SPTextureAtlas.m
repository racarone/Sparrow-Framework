//
//  SPTextureAtlas.m
//  Sparrow
//
//  Created by Daniel Sperl on 27.06.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPGLTexture.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPSubTexture.h>
#import <Sparrow/SPTexture.h>
#import <Sparrow/SPTextureAtlas.h>
#import <Sparrow/SPUtils.h>

// --- helper class --------------------------------------------------------------------------------

@interface SPTextureInfo : NSObject
{
    SPRectangle *_region;
    SPRectangle *_frame;
    BOOL _rotated;
}

- (instancetype)initWithRegion:(SPRectangle *)region frame:(SPRectangle *)frame
                       rotated:(BOOL)rotated;

@property (nonatomic, readonly) SPRectangle *region;
@property (nonatomic, readonly) SPRectangle *frame;
@property (nonatomic, readonly) BOOL rotated;

@end

@implementation SPTextureInfo

- (instancetype)initWithRegion:(SPRectangle *)region frame:(SPRectangle *)frame
                       rotated:(BOOL)rotated;
{
    if ((self = [super init]))
    {
        _region  = [region copy];
        _frame   = [frame  copy];
        _rotated = rotated;
    }
    return self;
}

- (void)dealloc
{
    [_region release];
    [_frame release];
    [super dealloc];
}

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPTextureAtlas
{
    SPTexture *_atlasTexture;
    NSMutableDictionary *_textureInfos;
}

@synthesize texture = _atlasTexture;

#pragma mark Initialization

- (instancetype)initWithContentsOfFile:(NSString *)path texture:(SPTexture *)texture
{
    if ((self = [super init]))
    {
        _textureInfos = [[NSMutableDictionary alloc] init];
        _atlasTexture = [texture retain];
        [self parseAtlasXml:path];
    }
    return self;    
}

- (instancetype)initWithContentsOfFile:(NSString *)path
{
    return [self initWithContentsOfFile:path texture:nil];
}

- (instancetype)initWithTexture:(SPTexture *)texture
{
    return [self initWithContentsOfFile:nil texture:(SPTexture *)texture];
}

- (instancetype)init
{
    return [self initWithContentsOfFile:nil texture:nil];
}

- (void)dealloc
{
    [_atlasTexture release];
    [_textureInfos release];
    [super dealloc];
}

+ (instancetype)atlasWithContentsOfFile:(NSString *)path
{
    return [[[self alloc] initWithContentsOfFile:path] autorelease];
}

#pragma mark Methods

- (SPTexture *)textureByName:(NSString *)name
{
    SPTextureInfo *info = _textureInfos[name];
    SPSubTexture *texture = nil;

    if (info)
    {
        texture = [[SPSubTexture alloc] initWithRegion:info.region frame:info.frame
                                               rotated:info.rotated ofTexture:_atlasTexture];
        [texture autorelease];
    }

    return texture;
}

- (SPRectangle *)regionByName:(NSString *)name
{
    SPTextureInfo *info = _textureInfos[name];
    return info.region;
}

- (SPRectangle *)frameByName:(NSString *)name
{
    SPTextureInfo *info = _textureInfos[name];
    return info.frame;
}

- (NSArray *)texturesStartingWith:(NSString *)prefix
{
    NSArray *names = [self namesStartingWith:prefix];
    
    NSMutableArray *textures = [NSMutableArray arrayWithCapacity:names.count];
    for (NSString *textureName in names)
        [textures addObject:[self textureByName:textureName]];
    
    return textures;
}

- (NSArray *)namesStartingWith:(NSString *)prefix
{
    NSMutableArray *names = [NSMutableArray array];
    
    if (prefix)
    {
        for (NSString *name in _textureInfos)
            if ([name rangeOfString:prefix].location == 0)
                [names addObject:name];
    }
    else
        [names addObjectsFromArray:[_textureInfos allKeys]];
    
    [names sortUsingSelector:@selector(localizedStandardCompare:)];
    return names;
}

- (void)addRegion:(SPRectangle *)region withName:(NSString *)name
{
    [self addRegion:region withName:name frame:nil rotated:NO];
}

- (void)addRegion:(SPRectangle *)region withName:(NSString *)name frame:(SPRectangle *)frame
{
    [self addRegion:region withName:name frame:frame rotated:NO];
}

- (void)addRegion:(SPRectangle *)region withName:(NSString *)name frame:(SPRectangle *)frame
          rotated:(BOOL)rotated
{
    SPTextureInfo *info = [[SPTextureInfo alloc] initWithRegion:region frame:frame rotated:rotated];
    _textureInfos[name] = info;
    [info release];
}

- (void)removeRegion:(NSString *)name
{
    [_textureInfos removeObjectForKey:name];
}

#pragma mark Properties

- (int)numTextures
{
    return (int)[_textureInfos count];
}

- (NSArray *)names
{
    return [self namesStartingWith:nil];
}

- (NSArray *)textures
{
    return [self texturesStartingWith:nil];
}

#pragma mark Private

- (void)parseAtlasXml:(NSString *)relativePath
{
    if (!relativePath) return;

    NSString *path = [SPUtils absolutePathToFile:relativePath];
    if (!path) [NSException raise:SPExceptionFileNotFound format:@"file not found: %@", relativePath];

    NSData *xmlData = [[NSData alloc] initWithContentsOfFile:path];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xmlData];
    [xmlData release];

    BOOL success = [parser parseElementsWithBlock:^(NSString *elementName, NSDictionary *attributes)
    {
        if ([elementName isEqualToString:@"SubTexture"])
        {
            float scale = _atlasTexture.scale;

            NSString *name = attributes[@"name"];
            float x = [attributes[@"x"] floatValue] / scale;
            float y = [attributes[@"y"] floatValue] / scale;
            float width = [attributes[@"width"] floatValue] / scale;
            float height = [attributes[@"height"] floatValue] / scale;
            float frameX = [attributes[@"frameX"] floatValue] / scale;
            float frameY = [attributes[@"frameY"] floatValue] / scale;
            float frameWidth = [attributes[@"frameWidth"] floatValue] / scale;
            float frameHeight = [attributes[@"frameHeight"] floatValue] / scale;
            BOOL  rotated = [attributes[@"rotated"] boolValue];

            SPRectangle *region = [SPRectangle rectangleWithX:x y:y width:width height:height];
            SPRectangle *frame = nil;

            if (frameWidth && frameHeight)
                frame = [SPRectangle rectangleWithX:frameX y:frameY width:frameWidth height:frameHeight];

            [self addRegion:region withName:name frame:frame rotated:rotated];
        }
        else if ([elementName isEqualToString:@"TextureAtlas"] && !_atlasTexture)
        {
            // load atlas texture
            NSString *filename = [attributes valueForKey:@"imagePath"];
            NSString *textureFolder = [path stringByDeletingLastPathComponent];
            NSString *texturePath = [textureFolder stringByAppendingPathComponent:filename];
            _atlasTexture = [[SPTexture alloc] initWithContentsOfFile:texturePath];
        }
    }];

    [parser release];
    
    if (!success)
        [NSException raise:SPExceptionFileInvalid format:@"could not parse texture atlas %@. Error: %@",
         path, parser.parserError.localizedDescription];
}

@end
