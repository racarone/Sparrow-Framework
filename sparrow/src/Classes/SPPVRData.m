//
//  SPPVRData.m
//  Sparrow
//
//  Created by Daniel Sperl on 23.11.13.
//
//

#import <Sparrow/SPMacros.h>
#import <Sparrow/SPPVRData.h>
#import <Sparrow/SPNSExtensions.h>

// --- PVR structs & enums -------------------------------------------------------------------------

#define PVRTEX_IDENTIFIER 0x21525650 // = the characters 'P', 'V', 'R'

typedef struct
{
	uint headerSize;          // size of the structure
	uint height;              // height of surface to be created
	uint width;               // width of input surface
	uint numMipmaps;          // number of mip-map levels requested
	uint pfFlags;             // pixel format flags
	uint textureDataSize;     // total size in bytes
	uint bitCount;            // number of bits per pixel
	uint rBitMask;            // mask for red bit
	uint gBitMask;            // mask for green bits
	uint bBitMask;            // mask for blue bits
	uint alphaBitMask;        // mask for alpha channel
	uint pvr;                 // magic number identifying pvr file
	uint numSurfs;            // number of surfaces present in the pvr
} PVRTextureHeader;

enum PVRPixelType
{
	OGL_RGBA_4444 = 0x10,
	OGL_RGBA_5551,
	OGL_RGBA_8888,
	OGL_RGB_565,
	OGL_RGB_555,
	OGL_RGB_888,
	OGL_I_8,
	OGL_AI_88,
	OGL_PVRTC2,
	OGL_PVRTC4,
    OGL_BGRA_8888,
    OGL_A_8
};

// --- class implementation ------------------------------------------------------------------------

@implementation SPPVRData
{
    NSData *_data;
}

#pragma mark Initialization

- (instancetype)initWithData:(NSData *)data
{
    return [self initWithData:data compressed:NO];
}

- (instancetype)initWithData:(NSData *)data compressed:(BOOL)isCompressed
{
    if ((self = [super init]))
    {
        if (isCompressed) _data = [[data gzipInflate] retain];
        else              _data =  [data retain];
        
        PVRTextureHeader *header = (PVRTextureHeader *)[_data bytes];
        bool hasAlpha = header->alphaBitMask ? YES : NO;
        
        _width      = header->width;
        _height     = header->height;
        _numMipmaps = header->numMipmaps;
        
        switch (header->pfFlags & 0xff)
        {
            case OGL_RGB_565:   _format = SPTextureFormat565;   break;
            case OGL_RGB_888:   _format = SPTextureFormat888;   break;
            case OGL_RGBA_5551: _format = SPTextureFormat5551;  break;
            case OGL_RGBA_4444: _format = SPTextureFormat4444;  break;
            case OGL_RGBA_8888: _format = SPTextureFormatRGBA;  break;
            case OGL_A_8:       _format = SPTextureFormatAlpha; break;
            case OGL_I_8:       _format = SPTextureFormatI8;    break;
            case OGL_AI_88:     _format = SPTextureFormatAI88;  break;
            case OGL_PVRTC2:
                _format = hasAlpha ? SPTextureFormatPvrtcRGBA2 : SPTextureFormatPvrtcRGB2;
                break;
            case OGL_PVRTC4:
                _format = hasAlpha ? SPTextureFormatPvrtcRGBA4 : SPTextureFormatPvrtcRGB4;
                break;
            default:
                [NSException raise:SPExceptionDataInvalid format:@"Unsupported PVR image format"];
                return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    [_data release];
    [super dealloc];
}

#pragma mark Properties

- (void *)imageData
{
    PVRTextureHeader *header = (PVRTextureHeader *)[_data bytes];
    return (unsigned char *)header + header->headerSize;
}

@end
