//
//  SPTexture.m
//  Sparrow
//
//  Created by Daniel Sperl on 19.06.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPGLTexture.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPPVRData.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPStage.h>
#import <Sparrow/SPSubTexture.h>
#import <Sparrow/SPTexture.h>
#import <Sparrow/SPURLConnection.h>
#import <Sparrow/SPUtils.h>
#import <Sparrow/SPVertexData.h>

// --- class implementation ------------------------------------------------------------------------

@implementation SPTexture

#pragma mark Initialization

- (instancetype)init
{    
    if ([self isMemberOfClass:[SPTexture class]]) 
    {
        return [self initWithWidth:32 height:32];
    }
    
    return [super init];
}

- (instancetype)initWithContentsOfFile:(NSString *)path
{
    return [self initWithContentsOfFile:path generateMipmaps:NO];
}

- (instancetype)initWithContentsOfFile:(NSString *)path generateMipmaps:(BOOL)mipmaps
{
    NSString *fullPath = [SPUtils absolutePathToFile:path];
    
    if (!fullPath)
        [NSException raise:SPExceptionFileNotFound format:@"File '%@' not found", path];
    
    if ([SPTexture isPVRFile:fullPath])
    {
        BOOL isCompressed = [SPTexture isCompressedFile:fullPath];
        float scale = [fullPath contentScaleFactor];
        
        NSData *rawData = [[NSData alloc] initWithContentsOfFile:fullPath];
        SPPVRData *pvrData = [[SPPVRData alloc] initWithData:rawData compressed:isCompressed];
        
        [self release]; // we'll return a subclass!
        self = [[SPGLTexture alloc] initWithPVRData:pvrData scale:scale];

        [rawData release];
        [pvrData release];

        return self;
    }
    else
    {
        // load image via this crazy workaround to be sure that path is not extended with scale
        NSData *data = [[NSData alloc] initWithContentsOfFile:fullPath];
        UIImage *image1 = [[UIImage alloc] initWithData:data];
        UIImage *image2 = [[UIImage alloc] initWithCGImage:image1.CGImage
           scale:[fullPath contentScaleFactor] orientation:UIImageOrientationUp];
        
        self = [self initWithContentsOfImage:image2 generateMipmaps:mipmaps];
        
        [image2 release];
        [image1 release];
        [data release];
        
        return self;
    }
}

- (instancetype)initWithWidth:(float)width height:(float)height
{
    return [self initWithWidth:width height:height draw:NULL];
}

- (instancetype)initWithWidth:(float)width height:(float)height draw:(SPTextureDrawingBlock)drawingBlock
{
    return [self initWithWidth:width height:height generateMipmaps:NO draw:drawingBlock];
}

- (instancetype)initWithWidth:(float)width height:(float)height generateMipmaps:(BOOL)mipmaps
               draw:(SPTextureDrawingBlock)drawingBlock
{
    return [self initWithWidth:width height:height generateMipmaps:mipmaps
                         scale:Sparrow.contentScaleFactor draw:drawingBlock];
}

- (instancetype)initWithWidth:(float)width height:(float)height generateMipmaps:(BOOL)mipmaps
              scale:(float)scale draw:(SPTextureDrawingBlock)drawingBlock
{
    [self release]; // class factory - we'll return a subclass!

    // only textures with sidelengths that are powers of 2 support all OpenGL ES features.
    int legalWidth  = [SPUtils nextPowerOfTwo:width  * scale];
    int legalHeight = [SPUtils nextPowerOfTwo:height * scale];
    
    CGColorSpaceRef cgColorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
    int bytesPerPixel = 4;
    
    void *imageData = calloc(legalWidth * legalHeight * bytesPerPixel, 1);
    CGContextRef context = CGBitmapContextCreate(imageData, legalWidth, legalHeight, 8, 
                                                 bytesPerPixel * legalWidth, cgColorSpace, 
                                                 bitmapInfo);
    CGColorSpaceRelease(cgColorSpace);
    
    // UIKit referential is upside down - we flip it and apply the scale factor
    CGContextTranslateCTM(context, 0.0f, legalHeight);
	CGContextScaleCTM(context, scale, -scale);
   
    if (drawingBlock)
    {
        UIGraphicsPushContext(context);
        drawingBlock(context);
        UIGraphicsPopContext();        
    }
    
    SPTextureProperties properties = {
        .format = SPTextureFormatRGBA,
        .scale  = scale,
        .width  = legalWidth,
        .height = legalHeight,
        .numMipmaps = 0,
        .generateMipmaps = mipmaps,
        .premultipliedAlpha = YES
    };
    
    SPGLTexture *glTexture = [[[SPGLTexture alloc]
                               initWithData:imageData properties:properties] autorelease];
    
    CGContextRelease(context);
    free(imageData);
    
    SPRectangle *region = [SPRectangle rectangleWithX:0 y:0 width:width height:height];
    return [[SPTexture alloc] initWithRegion:region ofTexture:glTexture];
}

- (instancetype)initWithContentsOfImage:(UIImage *)image
{
    return [self initWithContentsOfImage:image generateMipmaps:NO];
}

- (instancetype)initWithContentsOfImage:(UIImage *)image generateMipmaps:(BOOL)mipmaps
{
    return [self initWithWidth:image.size.width height:image.size.height generateMipmaps:mipmaps
                         scale:image.scale draw:^(CGContextRef context)
            {
                [image drawAtPoint:CGPointMake(0, 0)];
            }];
}

- (instancetype)initWithRegion:(SPRectangle *)region ofTexture:(SPTexture *)texture
{
    return [self initWithRegion:region frame:nil ofTexture:texture];
}

- (instancetype)initWithRegion:(SPRectangle *)region frame:(SPRectangle *)frame ofTexture:(SPTexture *)texture
{
    [self release]; // class factory - we'll return a subclass!

    if (frame || region.x != 0.0f || region.width  != texture.width
              || region.y != 0.0f || region.height != texture.height)
    {
        return [[SPSubTexture alloc] initWithRegion:region frame:frame ofTexture:texture];
    }
    else
    {
        return [texture retain];
    }
}

+ (instancetype)textureWithContentsOfFile:(NSString *)path
{
    return [[[self alloc] initWithContentsOfFile:path] autorelease];
}

+ (instancetype)textureWithContentsOfFile:(NSString *)path generateMipmaps:(BOOL)mipmaps
{
    return [[[self alloc] initWithContentsOfFile:path generateMipmaps:mipmaps] autorelease];
}

+ (instancetype)textureWithRegion:(SPRectangle *)region ofTexture:(SPTexture *)texture
{
    return [[[self alloc] initWithRegion:region ofTexture:texture] autorelease];
}

+ (instancetype)textureWithWidth:(float)width height:(float)height draw:(SPTextureDrawingBlock)drawingBlock
{
    return [[[self alloc] initWithWidth:width height:height draw:drawingBlock] autorelease];
}

+ (instancetype)emptyTexture
{
    return [[[self alloc] init] autorelease];
}

#pragma mark Methods

- (void)adjustVertexData:(SPVertexData *)vertexData atIndex:(int)index numVertices:(int)count
{
    // override in subclasses
}

- (void)adjustTexCoords:(void *)data numVertices:(int)count stride:(int)stride
{
    // override in subclasses
}

- (void)adjustPositions:(void *)data numVertices:(int)count stride:(int)stride
{
    // override in subclasses
}

#pragma mark Asynchronous Texture Loading

+ (void)loadFromFile:(NSString *)path onComplete:(SPTextureLoadingBlock)callback
{
    [self loadFromFile:path generateMipmaps:NO onComplete:callback];
}

+ (void)loadFromFile:(NSString *)path generateMipmaps:(BOOL)mipmaps
          onComplete:(SPTextureLoadingBlock)callback
{
    NSString *fullPath = [SPUtils absolutePathToFile:path];

    if (!fullPath)
        [NSException raise:SPExceptionFileNotFound format:@"File '%@' not found", path];

    [Sparrow.currentController executeInResourceQueue:^
     {
         NSError *error = nil;
         SPTexture *texture = nil;

         @try
         {
             texture = [[SPTexture alloc] initWithContentsOfFile:fullPath generateMipmaps:mipmaps];
         }
         @catch (NSException *exception)
         {
             error = [NSError errorWithDomain:exception.name code:0 userInfo:exception.userInfo];
         }

         dispatch_async(dispatch_get_main_queue(), ^
                        {
                            callback(texture, error);
                            [texture release];
                        });
     }];
}

+ (void)loadFromURL:(NSURL *)url onComplete:(SPTextureLoadingBlock)callback
{
    [self loadFromURL:url generateMipmaps:NO onComplete:callback];
}

+ (void)loadFromURL:(NSURL *)url generateMipmaps:(BOOL)mipmaps
         onComplete:(SPTextureLoadingBlock)callback
{
    float scale = [[url path] contentScaleFactor];
    [self loadFromURL:url generateMipmaps:mipmaps scale:scale onComplete:callback];
}

+ (void)loadFromURL:(NSURL *)url generateMipmaps:(BOOL)mipmaps scale:(float)scale
         onComplete:(SPTextureLoadingBlock)callback
{
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    SPURLConnection *connection = [[SPURLConnection alloc] initWithRequest:request];

    [connection startWithBlock:^(NSData *body, NSInteger httpStatus, NSError *error)
     {
         [Sparrow.currentController executeInResourceQueue:^
          {
              NSError *error = nil;
              SPTexture *texture = nil;

              @try
              {
                  UIImage *image = [UIImage imageWithData:body scale:scale];
                  texture = [[SPTexture alloc] initWithContentsOfImage:image generateMipmaps:mipmaps];
              }
              @catch (NSException *exception)
              {
                  error = [NSError errorWithDomain:exception.name code:0 userInfo:exception.userInfo];
              }

              dispatch_async(dispatch_get_main_queue(), ^
                             {
                                 callback(texture, error);
                                 [connection release];
                                 [texture release];
                             });
          }];
     }];
}

+ (void)loadFromSuffixedURL:(NSURL *)url onComplete:(SPTextureLoadingBlock)callback
{
    [self loadFromSuffixedURL:url generateMipmaps:NO onComplete:callback];
}

+ (void)loadFromSuffixedURL:(NSURL *)url generateMipmaps:(BOOL)mipmaps
                 onComplete:(SPTextureLoadingBlock)callback
{
    float scale = Sparrow.contentScaleFactor;
    NSString *suffixedString = [[url absoluteString] stringByAppendingScaleSuffixToFilename:scale];
    NSURL *suffixedURL = [NSURL URLWithString:suffixedString];
    [self loadFromURL:suffixedURL generateMipmaps:mipmaps scale:scale onComplete:callback];
}

#pragma mark Properties

- (float)width
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'width' in subclasses."];
    return 0;
}

- (float)height
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'height' in subclasses."];
    return 0;
}

- (float)nativeWidth
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'nativeWidth' in subclasses."];
    return 0;
}

- (float)nativeHeight
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'nativeHeight' in subclasses."];
    return 0;
}

- (SPGLTexture *)root
{
    return nil;
}

- (uint)name
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'name' in subclasses."];
    return 0;    
}

- (void)setRepeat:(BOOL)value
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'setRepeat:' in subclasses."];    
}

- (BOOL)repeat
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'repeat' in subclasses."];
    return NO;
}

- (SPTextureSmoothing)smoothing
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'smoothing' in subclasses."];
    return SPTextureSmoothingBilinear;
}

- (void)setSmoothing:(SPTextureSmoothing)filter
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'setSmoothing' in subclasses."];
}

- (BOOL)premultipliedAlpha
{
    return NO;
}

- (float)scale
{
    return 1.0f;
}

- (SPRectangle *)frame
{
    return nil;
}

#pragma mark Private

+ (BOOL)isPVRFile:(NSString *)path
{
    path = [path lowercaseString];
    return [path hasSuffix:@".pvr"] || [path hasSuffix:@".pvr.gz"];
}

+ (BOOL)isCompressedFile:(NSString *)path
{
    return [[path lowercaseString] hasSuffix:@".gz"];
}

@end
