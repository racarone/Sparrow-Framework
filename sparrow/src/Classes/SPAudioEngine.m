//
//  SPAudioEngine.m
//  Sparrow
//
//  Created by Daniel Sperl on 14.11.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPAudioEngine.h"
#import "SPMacros.h"

#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioServices.h>
#import <AudioToolbox/AudioToolbox.h>

#import <OpenAL/al.h>
#import <OpenAL/alc.h>

#import <UIKit/UIKit.h>

@interface SPAudioEngine ()

+ (BOOL)initAudioSession:(SPAudioSessionCategory)category;
+ (BOOL)initOpenAL;

+ (void)beginInterruption;
+ (void)endInterruption;

+ (void)postNotification:(NSString*)name object:(id)object;

@end

@implementation SPAudioEngine

// --- C functions ---

static void interruptionCallback (void* inUserData, UInt32 interruptionState)
{
    if (interruptionState == kAudioSessionBeginInterruption)
        [SPAudioEngine beginInterruption];
    else if (interruptionState == kAudioSessionEndInterruption)
        [SPAudioEngine endInterruption];
} 

// --- static members ---

static ALCdevice*   gDevice         = NULL;
static ALCcontext*  gContext        = NULL;
static float        gMasterVolume   = 1.0f;
static BOOL         gInterrupted    = NO;

// ---

- (instancetype)init
{
    [NSException raise:NSGenericException format:@"Static class - do not initialize!"];        
    return nil;
}

+ (void)start:(SPAudioSessionCategory)category
{
    if (!gDevice)
    {
        if ([SPAudioEngine initAudioSession:category])
            [SPAudioEngine initOpenAL];

        // A bug introduced in iOS 4 may lead to 'endInterruption' NOT being called in some
        // situations. Thus, we're resuming the audio session manually via the 'DidBecomeActive'
        // notification. Find more information here: http://goo.gl/mr9KS

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppActivated:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
}

+ (void)start
{      
    [SPAudioEngine start:SPAudioSessionCategory_SoloAmbientSound];
}

+ (void)stop
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    alcMakeContextCurrent(NULL);
    alcDestroyContext(gContext);
    alcCloseDevice(gDevice);
    AudioSessionSetActive(NO);
    
    gDevice = NULL;
    gContext = NULL;
    gInterrupted = NO;
}

+ (BOOL)initAudioSession:(SPAudioSessionCategory)category
{
    static BOOL sessionInitialized = NO;
    OSStatus result;
    
    if (!sessionInitialized)
    {
        result = AudioSessionInitialize(NULL, NULL, interruptionCallback, NULL);
        if (result != kAudioSessionNoError)        
        {        
            NSLog(@"Could not initialize audio session: %x", (unsigned int)result);
            return NO;
        }        
        sessionInitialized = YES;
    }
    
    UInt32 sessionCategory = category;
    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,                             
                            sizeof(sessionCategory), &sessionCategory);
    
    result = AudioSessionSetActive(YES);
    if (result != kAudioSessionNoError)
    {
        NSLog(@"Could not activate audio session: %x", (unsigned int)result);
        return NO;
    }
    
    return YES;
}

+ (BOOL)initOpenAL
{
    alGetError(); // reset any errors
    
    gDevice = alcOpenDevice(NULL);
    if (!gDevice)
    {
        NSLog(@"Could not open default OpenAL device");
        return NO;
    }
    
    gContext = alcCreateContext(gDevice, 0);
    if (!gContext)
    {
        NSLog(@"Could not create OpenAL context for default device");
        return NO;
    }
    
    BOOL success = alcMakeContextCurrent(gContext);
    if (!success)
    {
        NSLog(@"Could not set current OpenAL context");
        return NO;
    }
    
    return YES;
}

+ (void)beginInterruption
{
    [SPAudioEngine postNotification:SP_NOTIFICATION_AUDIO_INTERRUPTION_BEGAN object:nil];
    alcMakeContextCurrent(NULL);
    AudioSessionSetActive(NO);
    gInterrupted = YES;
}

+ (void)endInterruption
{
    gInterrupted = NO;
    AudioSessionSetActive(YES);
    alcMakeContextCurrent(gContext);
    alcProcessContext(gContext);
    [SPAudioEngine postNotification:SP_NOTIFICATION_AUDIO_INTERRUPTION_ENDED object:nil];
}

+ (void)onAppActivated:(NSNotification*)notification
{
    if (gInterrupted) [self endInterruption];
}

+ (float)masterVolume
{
    return gMasterVolume;
}

+ (void)setMasterVolume:(float)volume
{       
    gMasterVolume = volume;
    alListenerf(AL_GAIN, volume);
    [SPAudioEngine postNotification:SP_NOTIFICATION_MASTER_VOLUME_CHANGED object:nil];
}

+ (void)postNotification:(NSString*)name object:(id)object
{
    [[NSNotificationCenter defaultCenter] postNotification:
     [NSNotification notificationWithName:name object:object]]; 
}

@end
