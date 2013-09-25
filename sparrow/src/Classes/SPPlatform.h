//
//  SPPlatform.h
//  Sparrow
//
//  Created by Robert Carone on 9/24/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#include <Availability.h>
#include <AvailabilityMacros.h>
#include <TargetConditionals.h>

#if TARGET_OS_IPHONE
    #define SP_OS_IPHONE                        1

    #if TARGET_IPHONE_SIMULATOR
        #define SP_OS_IPHONE_SIMULATOR          1
    #else
        #define SP_OS_IPHONE_DEVICE             1
    #endif

#else
    #define SP_OS_OSX                           1
#endif

