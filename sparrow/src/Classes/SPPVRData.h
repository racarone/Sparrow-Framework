//
//  SPPVRData.h
//  Sparrow
//
//  Created by Daniel Sperl on 23.11.13.
//
//

#import <Foundation/Foundation.h>
#import <Sparrow/SPGLTexture.h>

/// A class that can be used to parse PVR texture data.
@interface SPPVRData : NSObject

/// --------------------
/// @name Initialization
/// --------------------

/// Initializes the object with uncompressed PVR data.
- (instancetype)initWithData:(NSData *)data;

/// Initialzes the object with PVR data that's optional GZIP compressed.
- (instancetype)initWithData:(NSData *)data compressed:(BOOL)isCompressed;

/// ----------------
/// @name Properties
/// ----------------

/// The width of the PVR texture in pixels.
@property (nonatomic, readonly) int width;

/// The height of the PVR texture in pixels.
@property (nonatomic, readonly) int height;

/// The number of mipmaps that's included in the PVR texture.
@property (nonatomic, readonly) int numMipmaps;

/// The texture format of the PVR texture.
@property (nonatomic, readonly) SPTextureFormat format;

/// A pointer to the raw image data of the PVR data.
@property (nonatomic, readonly) void *imageData;

@end
