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

#import "SPMacros.h"
#import "SPSoundChannel.h"

@implementation SPSoundChannel

- (instancetype)init
{
    if ([self isMemberOfClass:[SPSoundChannel class]]) 
    {
        [NSException raise:SP_EXC_ABSTRACT_CLASS 
                    format:@"Attempting to initialize abstract class SPSoundChannel."];        
        return nil;
    }
    
    return [super init];
}

- (void)play
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'play' in subclasses."];
}

- (void)pause
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'pause' in subclasses."];
}

- (void)stop
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'stop' in subclasses."];
}

- (BOOL)isPlaying
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'isPlaying' in subclasses."];
    return NO;
}

- (BOOL)isPaused
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'isPaused' in subclasses."];
    return NO;
}

- (BOOL)isStopped
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'isStopped' in subclasses."];
    return NO;
}

- (BOOL)loop
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'loop' in subclasses."];
    return NO;
}

- (void)setLoop:(BOOL)value
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'setLoop:' in subclasses."];
}

- (float)volume
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'volume' in subclasses."];
    return 1.0f;
}

- (void)setVolume:(float)value
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'setVolume' in subclasses."];
}

- (double)duration
{
    [NSException raise:SP_EXC_ABSTRACT_METHOD format:@"Override 'duration' in subclasses."];
    return 0.0;
}

@end
