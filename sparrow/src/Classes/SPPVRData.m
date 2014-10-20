//
//  SPPVRData.m
//  Sparrow
//
//  Created by Daniel Sperl on 23.11.13.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Sparrow/SPMacros.h>
#import <Sparrow/SPPVRData.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPUtils.h>

// --- PVR structs & enums -------------------------------------------------------------------------

static const char PVR_IDENTIFIER[4] = "PVR!";

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
    if ((self = [super init]))
    {
        if ([SPUtils isGZIPCompressed:data]) _data = [[data gzipInflate] retain];
        else                                 _data =  [data retain];

        if (![[self class] isPVRData:_data])
            [NSException raise:SPExceptionInvalidOperation format:@"Data is not a PVR image"];
        
        PVRTextureHeader *header = (PVRTextureHeader *)[_data bytes];
        bool hasAlpha = header->alphaBitMask ? YES : NO;

        _width = header->width;
        _height = header->height;
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

#pragma mark Private

+ (BOOL)isPVRData:(NSData *)data
{
    PVRTextureHeader *header = (PVRTextureHeader *)[data bytes];
    int pvrTag = CFSwapInt32LittleToHost(header->pvr);

    if (PVR_IDENTIFIER[0] != ((pvrTag >>  0) & 0xff) ||
        PVR_IDENTIFIER[1] != ((pvrTag >>  8) & 0xff) ||
        PVR_IDENTIFIER[2] != ((pvrTag >> 16) & 0xff) ||
        PVR_IDENTIFIER[3] != ((pvrTag >> 24) & 0xff))
        return NO;

    return YES;
}

@end
