//
//  SPALSound.m
//  Sparrow
//
//  Created by Daniel Sperl on 28.05.10.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPALSound.h"
#import "SPALSoundChannel.h"
#import "SPAudioEngine.h"

#import <OpenAL/al.h>
#import <OpenAL/alc.h>

@implementation SPALSound
{
    uint mBufferID;
    double mDuration;
}

@synthesize duration = mDuration;
@synthesize bufferID = mBufferID;

- (id)init
{
    return nil;
}

- (id)initWithData:(const void *)data size:(int)size channels:(int)channels frequency:(int)frequency
          duration:(double)duration
{
    if ((self = [super init]))
    {        
        mDuration = duration;
        [SPAudioEngine start];
        
        ALCcontext *const currentContext = alcGetCurrentContext();
        if (!currentContext)
        {
            NSLog(@"Could not get current OpenAL context");
            return nil;
        }        
        
        ALenum errorCode;
        
        alGenBuffers(1, &mBufferID);
        errorCode = alGetError();
        if (errorCode != AL_NO_ERROR)
        {
            NSLog(@"Could not allocate OpenAL buffer (%x)", errorCode);
            return nil;
        }            
        
        int format = (channels > 1) ? AL_FORMAT_STEREO16 : AL_FORMAT_MONO16;
        
        alBufferData(mBufferID, format, data, size, frequency);
        errorCode = alGetError();
        if (errorCode != AL_NO_ERROR)
        {
            NSLog(@"Could not fill OpenAL buffer (%x)", errorCode);
            return nil;
        }
    }
    return self;
}

- (SPSoundChannel *)createChannel
{
    return [[SPALSoundChannel alloc] initWithSound:self];
}

- (void) dealloc
{
    alDeleteBuffers(1, &mBufferID);
    mBufferID = 0;
}

@end
