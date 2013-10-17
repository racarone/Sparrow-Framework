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

#import <Foundation/Foundation.h>
#import <math.h>

// typedefs

typedef void (^SPCallbackBlock)();

// defines

#define SP_DEPRECATED               __attribute__((deprecated))

#define SP_INLINE                   static __inline__

#ifdef __cplusplus
    #define SP_EXTERN               extern "C" __attribute__((visibility ("default")))
#else
    #define SP_EXTERN               extern __attribute__((visibility ("default")))
#endif

// constants

#define PI                          3.14159265359f
#define PI_HALF                     1.57079632679f
#define TWO_PI                      6.28318530718f

#define SP_FLOAT_EPSILON            0.0001f
#define SP_MAX_DISPLAY_TREE_DEPTH   32

SP_EXTERN const uint SPColorWhite;
SP_EXTERN const uint SPColorSilver;
SP_EXTERN const uint SPColorGray;
SP_EXTERN const uint SPColorBlack;
SP_EXTERN const uint SPColorRed;
SP_EXTERN const uint SPColorMaroon;
SP_EXTERN const uint SPColorYellow;
SP_EXTERN const uint SPColorOlive;
SP_EXTERN const uint SPColorLime;
SP_EXTERN const uint SPColorGreen;
SP_EXTERN const uint SPColorAqua;
SP_EXTERN const uint SPColorTeal;
SP_EXTERN const uint SPColorBlue;
SP_EXTERN const uint SPColorNavy;
SP_EXTERN const uint SPColorFuchsia;
SP_EXTERN const uint SPColorPurple;

enum {SPNotFound = -1};

// exceptions

SP_EXTERN NSString *const SPExceptionAbstractClass;
SP_EXTERN NSString *const SPExceptionAbstractMethod;
SP_EXTERN NSString *const SPExceptionNotRelated;
SP_EXTERN NSString *const SPExceptionIndexOutOfBounds;
SP_EXTERN NSString *const SPExceptionInvalidOperation;
SP_EXTERN NSString *const SPExceptionFileNotFound;
SP_EXTERN NSString *const SPExceptionFileInvalid;
SP_EXTERN NSString *const SPExceptionDataInvalid;
SP_EXTERN NSString *const SPExceptionOperationFailed;

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

#define SP_CLAMP(value, min, max)   MIN((max), MAX((value), (min)))

#define SP_SWAP(x, y, T)            do { T temp##x##y = x; x = y; y = temp##x##y; } while (0)

#define SP_SQUARE(x)                ((x)*(x))

// release and set value to nil

#if __has_feature(objc_arc)
    #define SP_RELEASE_AND_NIL(_var)            \
        _var = nil                              \

#else
    #define SP_RELEASE_AND_NIL(_var)            \
        do {                                    \
            [_var release];                     \
            _var = nil;                         \
        }                                       \
        while (0)                               \

#endif

// release old and retain new

#if __has_feature(objc_arc)
    #define SP_RELEASE_AND_RETAIN(_old, _new)   \
        _old = _new                             \

#else
    #define SP_RELEASE_AND_RETAIN(_old, _new)   \
        do {                                    \
            if (_old == _new) break;            \
            id tmp = _old;                      \
            _old = [_new retain];               \
            [tmp release];                      \
        }                                       \
        while (0)                               \

#endif

// release old and copy new

#if __has_feature(objc_arc)
    #define SP_RELEASE_AND_COPY(_old, _new)     \
        _old = [_new copy]                      \

#else
    #define SP_RELEASE_AND_COPY(_old, _new)     \
        do {                                    \
            if (_old == _new) break;            \
            id tmp = _old;                      \
            _old = [_new copy];                 \
            [tmp release];                      \
        }                                       \
        while (0)                               \

#endif

// autorelase value

#if __has_feature(objc_arc)
    #define SP_AUTORELEASE(_value)              \
        _value                                  \

#else
    #define SP_AUTORELEASE(_value)              \
        [_value autorelease]                    \

#endif

// deprecated

#define SP_NOT_FOUND                                SPNotFound

#define SP_BLEND_MODE_AUTO                          SPBlendModeAuto
#define SP_BLEND_MODE_NONE                          SPBlendModeNone
#define SP_BLEND_MODE_NORMAL                        SPBlendModeNormal
#define SP_BLEND_MODE_ADD                           SPBlendModeAdd
#define SP_BLEND_MODE_MULTIPLY                      SPBlendModeMultiply
#define SP_BLEND_MODE_SCREEN                        SPBlendModeScreen
#define SP_BLEND_MODE_ERASE                         SPBlendModeErase

#define SP_BITMAP_FONT_MINI                         SPBitmapFontMiniName
#define SP_DEFAULT_FONT_NAME                        SPDefaultFontName
#define SP_DEFAULT_FONT_SIZE                        SPDefaultFontSize
#define SP_DEFAULT_FONT_COLOR                       SPDefaultFontColor
#define SP_NATIVE_FONT_SIZE                         SPNativeFontSize

#define SP_WHITE                                    SPColorWhite
#define SP_SILVER                                   SPColorSilver
#define SP_GRAY                                     SPColorGray
#define SP_BLACK                                    SPColorBlack
#define SP_RED                                      SPColorRed
#define SP_MAROON                                   SPColorMaroon
#define SP_YELLOW                                   SPColorYellow
#define SP_OLIVE                                    SPColorOlive
#define SP_LIME                                     SPColorLime
#define SP_GREEN                                    SPColorGreen
#define SP_AQUA                                     SPColorAqua
#define SP_TEAL                                     SPColorTeal
#define SP_BLUE                                     SPColorBlue
#define SP_NAVY                                     SPColorNavy
#define SP_FUCHSIA                                  SPColorFuchsia
#define SP_PURPLE                                   SPColorPurple

#define SP_EVENT_TYPE_ADDED                         SPEventTypeAdded
#define SP_EVENT_TYPE_ADDED_TO_STAGE                SPEventTypeAddedToStage
#define SP_EVENT_TYPE_REMOVED                       SPEventTypeRemoved
#define SP_EVENT_TYPE_REMOVED_FROM_STAGE            SPEventTypeRemovedFromStage
#define SP_EVENT_TYPE_REMOVE_FROM_JUGGLER           SPEventTypeRemoveFromJuggler
#define SP_EVENT_TYPE_COMPLETED                     SPEventTypeCompleted
#define SP_EVENT_TYPE_TRIGGERED                     SPEventTypeTriggered
#define SP_EVENT_TYPE_FLATTEN                       SPEventTypeFlatten
#define SP_EVENT_TYPE_TOUCH                         SPEventTypeTouch
#define SP_EVENT_TYPE_ENTER_FRAME                   SPEventTypeEnterFrame
#define SP_EVENT_TYPE_RESIZE                        SPEventTypeResize

#define SP_EXC_ABSTRACT_CLASS                       SPExceptionAbstractClass
#define SP_EXC_ABSTRACT_METHOD                      SPExceptionAbstractMethod
#define SP_EXC_NOT_RELATED                          SPExceptionNotRelated
#define SP_EXC_INDEX_OUT_OF_BOUNDS                  SPExceptionIndexOutOfBounds
#define SP_EXC_INVALID_OPERATION                    SPExceptionInvalidOperation
#define SP_EXC_FILE_NOT_FOUND                       SPExceptionFileNotFound
#define SP_EXC_FILE_INVALID                         SPExceptionFileInvalid
#define SP_EXC_DATA_INVALID                         SPExceptionDataInvalid
#define SP_EXC_OPERATION_FAILED                     SPExceptionOperationFailed

#define SP_NOTIFICATION_MASTER_VOLUME_CHANGED       SPNotificationMasterVolumeChanged
#define SP_NOTIFICATION_AUDIO_INTERRUPTION_BEGAN    SPNotificationAudioInteruptionBegan
#define SP_NOTIFICATION_AUDIO_INTERRUPTION_ENDED    SPNotificationAudioInteruptionEnded

#define SP_TRANSITION_LINEAR                        SPTransitionLinear
#define SP_TRANSITION_RANDOMIZE                     SPTransitionRandomize
#define SP_TRANSITION_EASE_IN                       SPTransitionEaseIn
#define SP_TRANSITION_EASE_OUT                      SPTransitionEaseOut
#define SP_TRANSITION_EASE_IN_OUT                   SPTransitionEaseInOut
#define SP_TRANSITION_EASE_OUT_IN                   SPTransitionEaseOutIn
#define SP_TRANSITION_EASE_IN_BACK                  SPTransitionEaseInBack
#define SP_TRANSITION_EASE_OUT_BACK                 SPTransitionEaseOutBack
#define SP_TRANSITION_EASE_IN_OUT_BACK              SPTransitionEaseInOutBack
#define SP_TRANSITION_EASE_OUT_IN_BACK              SPTransitionEaseOutInBack
#define SP_TRANSITION_EASE_IN_ELASTIC               SPTransitionEaseInElastic
#define SP_TRANSITION_EASE_OUT_ELASTIC              SPTransitionEaseOutElastic
#define SP_TRANSITION_EASE_IN_OUT_ELASTIC           SPTransitionEaseInOutElastic
#define SP_TRANSITION_EASE_OUT_IN_ELASTIC           SPTransitionEaseOutInElastic
#define SP_TRANSITION_EASE_IN_BOUNCE                SPTransitionEaseInBounce
#define SP_TRANSITION_EASE_OUT_BOUNCE               SPTransitionEaseOutBounce
#define SP_TRANSITION_EASE_IN_OUT_BOUNCE            SPTransitionEaseInOutBounce
#define SP_TRANSITION_EASE_OUT_IN_BOUNCE            SPTransitionEaseOutInBounce
