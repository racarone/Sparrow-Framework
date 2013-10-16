//
//  SPSoundChannel.m
//  Sparrow
//
//  Created by Daniel Sperl on 14.11.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPSoundChannel.h"
#import "SPMacros.h"

@implementation SPSoundChannel

- (instancetype)init
{
    if ([self isMemberOfClass:[SPSoundChannel class]]) 
    {
        [NSException raise:SPExceptionAbstractClass
                    format:@"Attempting to initialize abstract class SPSoundChannel."];        
        return nil;
    }
    
    return [super init];
}

- (void)play
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'play' in subclasses."];
}

- (void)pause
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'pause' in subclasses."];
}

- (void)stop
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'stop' in subclasses."];
}

- (BOOL)isPlaying
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'isPlaying' in subclasses."];
    return NO;
}

- (BOOL)isPaused
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'isPaused' in subclasses."];
    return NO;
}

- (BOOL)isStopped
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'isStopped' in subclasses."];
    return NO;
}

- (BOOL)loop
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'loop' in subclasses."];
    return NO;
}

- (void)setLoop:(BOOL)value
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'setLoop:' in subclasses."];
}

- (float)volume
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'volume' in subclasses."];
    return 1.0f;
}

- (void)setVolume:(float)value
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'setVolume' in subclasses."];
}

- (double)duration
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'duration' in subclasses."];
    return 0.0;
}

@end
