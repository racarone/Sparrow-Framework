//
//  SPBlendMode.m
//  Sparrow
//
//  Created by Daniel Sperl on 29.03.13.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPBlendMode.h"
#import "SPOpenGL.h"

// --- public constants ----------------------------------------------------------------------------

const uint SPBlendModeAuto      = 0xffffffff;
const uint SPBlendModeNone      = 0x00001010;
const uint SPBlendModeNormal    = 0x00004515;
const uint SPBlendModeAdd       = 0x00004611;
const uint SPBlendModeMultiply  = 0x00008585;
const uint SPBlendModeScreen    = 0x00004113;
const uint SPBlendModeErase     = 0x00000505;

// --- C functions ---------------------------------------------------------------------------------

static inline uint encodeFactor(uint factor)
{
    if (factor == GL_ZERO || factor == GL_ONE) return factor;
    else return (factor & 0xf) + 2;
}

static inline uint decodeFactor(uint factor)
{
    if (factor == GL_ZERO || factor == GL_ONE) return factor;
    else return factor + 0x0300 - 2;
}

static NSString *getNameOfFactor(uint factor)
{
    switch (factor)
    {
        case GL_ZERO:                return @"ZERO"; break;
        case GL_ONE:                 return @"ONE"; break;
        case GL_SRC_COLOR:           return @"SRC_COLOR"; break;
        case GL_ONE_MINUS_SRC_COLOR: return @"ONE_MINUS_SRC_COLOR"; break;
        case GL_SRC_ALPHA:           return @"SRC_ALPHA"; break;
        case GL_ONE_MINUS_SRC_ALPHA: return @"ONE_MINUS_SRC_ALPHA"; break;
        case GL_DST_ALPHA:           return @"DST_ALPHA"; break;
        case GL_ONE_MINUS_DST_ALPHA: return @"ONE_MINUS_DST_ALPHA"; break;
        case GL_DST_COLOR:           return @"DST_COLOR"; break;
        case GL_ONE_MINUS_DST_COLOR: return @"ONE_MINUS_DST_COLOR"; break;
        case GL_SRC_ALPHA_SATURATE:  return @"SRC_ALPHA_SATURATE"; break;
        default:                     return @"unknown";  break;
    }
}

static NSString *getNameOfMode(uint mode)
{
    switch (mode)
    {
        case SPBlendModeAuto:       return @"auto";     break;
        case SPBlendModeNone:       return @"none";     break;
        case SPBlendModeNormal:     return @"normal";   break;
        case SPBlendModeAdd:        return @"add";      break;
        case SPBlendModeMultiply:   return @"multiply"; break;
        case SPBlendModeScreen:     return @"screen";   break;
        case SPBlendModeErase:      return @"erase";    break;
        default:                    return nil;         break;
    }
}

// --- Class implementation ------------------------------------------------------------------------

@implementation SPBlendMode

- (instancetype)init
{
    return nil;
}

// OpenGL blend factors are either 0, 1, or something between 0x0300 and 0x0308.
// We can use this to encode 4 blend factors in a single unsigned integer.

+ (uint)encodeBlendModeWithSourceFactor:(uint)sFactor destFactor:(uint)dFactor
{
    return [self encodeBlendModeWithSourceFactor:sFactor destFactor:dFactor
                                 sourceFactorPMA:sFactor destFactorPMA:dFactor];
}

+ (uint)encodeBlendModeWithSourceFactor:(uint)sFactor destFactor:(uint)dFactor
                        sourceFactorPMA:(uint)sFactorPMA destFactorPMA:(uint)dFactorPMA
{
    return ((encodeFactor(sFactor))    << 12) |
           ((encodeFactor(dFactor))    <<  8) |
           ((encodeFactor(sFactorPMA)) <<  4) |
           ( encodeFactor(dFactorPMA));
}

+ (void)decodeBlendMode:(uint)blendMode premultipliedAlpha:(BOOL)pma
       intoSourceFactor:(uint *)sFactor destFactor:(uint *)dFactor
{
    if (pma)
    {
        *sFactor = decodeFactor((blendMode & 0x00f0) >> 4);
        *dFactor = decodeFactor( blendMode & 0x000f);
    }
    else
    {
        *sFactor = decodeFactor((blendMode & 0xf000) >> 12);
        *dFactor = decodeFactor((blendMode & 0x0f00) >>  8);
    }
}

+ (void)applyBlendFactorsForBlendMode:(uint)blendMode premultipliedAlpha:(BOOL)pma
{
    uint srcFactor, dstFactor;

    if (blendMode == SPBlendModeNone)
        return glDisable(GL_BLEND);
    
    [self decodeBlendMode:blendMode premultipliedAlpha:pma intoSourceFactor:&srcFactor
               destFactor:&dstFactor];

    glEnable(GL_BLEND);
    glBlendFunc(srcFactor, dstFactor);
}

+ (NSString *)describeBlendMode:(uint)blendMode
{
    NSString *modeName = getNameOfMode(blendMode);
    
    if (modeName) return [NSString stringWithFormat:@"[BlendMode: %@]", modeName];
    else
    {
        uint src, dst, srcPMA, dstPMA;
        [self decodeBlendMode:blendMode premultipliedAlpha:NO  intoSourceFactor:&src destFactor:&dst];
        [self decodeBlendMode:blendMode premultipliedAlpha:YES intoSourceFactor:&srcPMA destFactor:&dstPMA];
        
        if (src == srcPMA && dst == dstPMA)
            return [NSString stringWithFormat:@"[BlendMode: src=%@, dst=%@]",
                    getNameOfFactor(src), getNameOfFactor(dst)];
        else
            return [NSString stringWithFormat:@"[BlendMode: src=%@, dst=%@, srcPMA=%@, dstPMA=%@]",
                getNameOfFactor(src),    getNameOfFactor(dst),
                getNameOfFactor(srcPMA), getNameOfFactor(dstPMA)];
    }
}

@end
