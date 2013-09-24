//
//  SPMacros.h
//  Sparrow
//
//  Created by Daniel Sperl on 15.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#if defined(__OBJC__)
    #import <Foundation/Foundation.h>
#else
    #include <CoreFoundation/CoreFoundation.h>
#endif

#import <math.h>

// typedefs

typedef void (^SPCallbackBlock)();

// defines

#ifdef __cplusplus
    #define SP_EXTERN       extern "C" __attribute__((visibility ("default")))
#else
    #define SP_EXTERN       extern __attribute__((visibility ("default")))
#endif

// constants

#define PI       3.14159265359f
#define PI_HALF  1.57079632679f
#define TWO_PI   6.28318530718f

#define SP_FLOAT_EPSILON 0.0001f

#define SP_WHITE     0xffffff
#define SP_SILVER    0xc0c0c0
#define SP_GRAY      0x808080
#define SP_BLACK     0x000000
#define SP_RED       0xff0000
#define SP_MAROON    0x800000
#define SP_YELLOW    0xffff00
#define SP_OLIVE     0x808000
#define SP_LIME      0x00ff00
#define SP_GREEN     0x008000
#define SP_AQUA      0x00ffff
#define SP_TEAL      0x008080
#define SP_BLUE      0x0000ff
#define SP_NAVY      0x000080
#define SP_FUCHSIA   0xff00ff
#define SP_PURPLE    0x800080

#define SP_NOT_FOUND -1
#define SP_MAX_DISPLAY_TREE_DEPTH 32

// exceptions

#define SP_EXC_ABSTRACT_CLASS       @"AbstractClass"
#define SP_EXC_ABSTRACT_METHOD      @"AbstractMethod"
#define SP_EXC_NOT_RELATED          @"NotRelated"
#define SP_EXC_INDEX_OUT_OF_BOUNDS  @"IndexOutOfBounds"
#define SP_EXC_INVALID_OPERATION    @"InvalidOperation"
#define SP_EXC_FILE_NOT_FOUND       @"FileNotFound"
#define SP_EXC_FILE_INVALID         @"FileInvalid"
#define SP_EXC_DATA_INVALID         @"DataInvalid"
#define SP_EXC_OPERATION_FAILED     @"OperationFailed"

// macros

#if __has_feature(objc_arc)
    #define SP_AUTORELEASE(_var) _var
#else
    #define SP_AUTORELEASE(_var) [_var autorelease]
#endif

#define SP_RETAIN_BLOCK(_var) \
    for (id __obj__ = [_var retain]; __obj__; [__obj__ release], __obj__ = nil)

#define SP_RELEASE_AND_NIL(_var) \
    [_var release]; _var = nil

#define SP_ASSIGN_RETAIN(_old, _new) \
    do {\
        if (_old == _new) break; \
        id tmp = _old;\
        _old = [_new retain];\
        [tmp release];\
    }\
    while (0)

#define SP_ASSIGN_COPY(_old, _new) \
    do {\
        if (_old == _new) break; \
        id tmp = _old;\
        _old = [_new copy];\
        [tmp release];\
    }\
while (0)

// macros

#define SP_R2D(rad)                 ((rad) / PI * 180.0f)
#define SP_D2R(deg)                 ((deg) / 180.0f * PI)

#define SP_COLOR_PART_ALPHA(color)  (((color) >> 24) & 0xff)
#define SP_COLOR_PART_RED(color)    (((color) >> 16) & 0xff)
#define SP_COLOR_PART_GREEN(color)  (((color) >>  8) & 0xff)
#define SP_COLOR_PART_BLUE(color)   ( (color)        & 0xff)

#define SP_COLOR(r, g, b)			(((int)(r) << 16) | ((int)(g) << 8) | (int)(b))
#define SP_COLOR_ARGB(a, r, g, b)   (((int)(a) << 24) | ((int)(r) << 16) | ((int)(g) << 8) | (int)(b))

#define SP_IS_FLOAT_EQUAL(f1, f2)   (fabsf((f1)-(f2)) < SP_FLOAT_EPSILON)

#define SP_SQUARE(x)                ((x) * (x))
#define SP_CLAMP(value, min, max)   MIN((max), MAX((value), (min)))

#define SP_SWAP(x, y, T)            do { T temp##x##y = x; x = y; y = temp##x##y; } while (0)

#define SP_DEPRECATED               __attribute__((deprecated))
