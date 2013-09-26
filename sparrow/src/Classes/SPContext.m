//
//  SPContext.m
//  Sparrow
//
//  Created by Robert Carone on 9/25/13.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPContext.h"

@implementation SPContext

#if SP_TARGET_IPHONE
+ (BOOL)setCurrentContext:(SPContext*)context
{
    return [super setCurrentContext:context];
}

+ (SPContext*)currentContext
{
    return (SPContext*)[super currentContext];
}
#else
+ (BOOL)setCurrentContext:(SPContext*)context
{
    [[self currentContext] makeCurrentContext];
    return YES;
}

+ (SPContext*)currentContext
{
    return (SPContext*)[super currentContext];
}

#endif

@end
