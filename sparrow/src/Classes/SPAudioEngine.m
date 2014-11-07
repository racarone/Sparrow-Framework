//
//  SPAudioEngine.m
//  Sparrow
//
//  Created by Daniel Sperl on 14.11.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPAudioEngine.h"

#import <AVFoundation/AVFoundation.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>
#import <UIKit/UIKit.h>

// --- notifications -------------------------------------------------------------------------------

NSString *const SPNotificationMasterVolumeChanged       = @"SPNotificationMasterVolumeChanged";
NSString *const SPNotificationAudioInteruptionBegan     = @"SPNotificationAudioInteruptionBegan";
NSString *const SPNotificationAudioInteruptionEnded     = @"SPNotificationAudioInteruptionEnded";

// --- class implementation ------------------------------------------------------------------------

@implementation SPAudioEngine

// --- static members ---

static ALCdevice  *device  = NULL;
static ALCcontext *context = NULL;
static float masterVolume = 1.0f;
static BOOL interrupted = NO;

#pragma mark Initialization

- (instancetype)init
{
    [NSException raise:NSGenericException format:@"Static class - do not initialize!"];        
    return nil;
}

+ (BOOL)initAudioSession:(SPAudioSessionCategory)category
{
    static BOOL sessionInitialized = NO;
    NSError *error = nil;

    if (!sessionInitialized)
    {
        [[AVAudioSession sharedInstance] setActive:YES error:&error];

        if (error)
        {
            NSLog(@"Could not activate audio session: %@", [error description]);
            return NO;
        }

        sessionInitialized = YES;
    }

    NSString *avCategory = nil;
    switch (category)
    {
        case SPAudioSessionCategory_AmbientSound:     avCategory = AVAudioSessionCategoryAmbient; break;
        case SPAudioSessionCategory_AudioProcessing:  avCategory = AVAudioSessionCategoryAudioProcessing; break;
        case SPAudioSessionCategory_MediaPlayback:    avCategory = AVAudioSessionCategoryMultiRoute; break;
        case SPAudioSessionCategory_PlayAndRecord:    avCategory = AVAudioSessionCategoryPlayAndRecord; break;
        case SPAudioSessionCategory_RecordAudio:      avCategory = AVAudioSessionCategoryRecord; break;
        case SPAudioSessionCategory_SoloAmbientSound: avCategory = AVAudioSessionCategorySoloAmbient; break;
    }

    [[AVAudioSession sharedInstance] setCategory:avCategory error:&error];

    if (error)
    {
        NSLog(@"Could not set audio category: %@", [error description]);
        return NO;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(onInterruption:)
			name:AVAudioSessionInterruptionNotification object:nil];

    return YES;
}

+ (BOOL)initOpenAL
{
    alGetError(); // reset any errors

    device = alcOpenDevice(NULL);
    if (!device)
    {
        NSLog(@"Could not open default OpenAL device");
        return NO;
    }

    context = alcCreateContext(device, 0);
    if (!context)
    {
        NSLog(@"Could not create OpenAL context for default device");
        return NO;
    }

    BOOL success = alcMakeContextCurrent(context);
    if (!success)
    {
        NSLog(@"Could not set current OpenAL context");
        return NO;
    }

    return YES;
}

#pragma mark Methods

+ (void)start:(SPAudioSessionCategory)category
{
    if (!device)
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
    alcDestroyContext(context);
    alcCloseDevice(device);
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
    
    device = NULL;
    context = NULL;
    interrupted = NO;
}

+ (float)masterVolume
{
    return masterVolume;
}

+ (void)setMasterVolume:(float)volume
{       
    masterVolume = volume;
    alListenerf(AL_GAIN, volume);
    [SPAudioEngine postNotification:SPNotificationMasterVolumeChanged object:nil];
}

#pragma mark Notifications

+ (void)onInterruption:(NSNotification *)notification
{
    NSDictionary *info = notification.userInfo;
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] integerValue];
    if (type == AVAudioSessionInterruptionTypeBegan)
        [self beginInterruption];
    else
    {
        BOOL shouldResume = [info[AVAudioSessionInterruptionOptionKey] integerValue];
        if (shouldResume)
            [self endInterruption];
    }
}

+ (void)beginInterruption
{
    [SPAudioEngine postNotification:SPNotificationAudioInteruptionBegan object:nil];
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
    alcMakeContextCurrent(NULL);

    interrupted = YES;
}

+ (void)endInterruption
{
    interrupted = NO;

    alcMakeContextCurrent(context);
    alcProcessContext(context);
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [SPAudioEngine postNotification:SPNotificationAudioInteruptionEnded object:nil];
}

+ (void)onAppActivated:(NSNotification *)notification
{
    if (interrupted) [self endInterruption];
}

+ (void)postNotification:(NSString *)name object:(id)object
{
    [[NSNotificationCenter defaultCenter] postNotification:
     [NSNotification notificationWithName:name object:object]];
}

@end
