//
//  SPPlatform.h
//  Sparrow
//
//  Created by Robert Carone on 9/24/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Availability.h>
#import <AvailabilityMacros.h>
#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
    #define SP_TARGET_IPHONE                    1

    #if TARGET_IPHONE_SIMULATOR
        #define SP_TARGET_IPHONE_SIMULATOR      1
    #else
        #define SP_TARGET_IPHONE_DEVICE         1
    #endif

#else
    #define SP_TARGET_OSX                       1
#endif

