//
//  SPContext.h
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPPlatform.h"

#if SP_TARGET_IPHONE
    #import <QuartzCore/QuartzCore.h>
    #define SP_NATIVE_CONTEXT EAGLContext
#else
    #import <AppKit/AppKit.h>
    #define SP_NATIVE_CONTEXT NSOpenGLContext
#endif

@interface SPContext : SP_NATIVE_CONTEXT

+ (BOOL)setCurrentContext:(SPContext*)context;
+ (SPContext*)currentContext;

@end
