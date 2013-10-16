//
//  SPSound.m
//  Sparrow
//
//  Created by Daniel Sperl on 14.11.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPSound.h"
#import "SPSoundChannel.h"
#import "SPMacros.h"
#import "SPEvent.h"
#import "SPALSound.h"
#import "SPAVSound.h"
#import "SPUtils.h"

#import <AudioToolbox/AudioToolbox.h> 

@implementation SPSound
{
    NSMutableSet *_playingChannels;
}

- (instancetype)init
{
    if ([self isMemberOfClass:[SPSound class]])
    {
        [NSException raise:SPExceptionAbstractClass
                    format:@"Attempting to initialize abstract class SPSound."];        
        return nil;
    }
    
    return [super init];
}

- (instancetype)initWithContentsOfFile:(NSString *)path
{
    // SPSound is a class factory! We'll return a subclass, thus we don't need 'self' anymore.
    [self release];
    
    NSString *fullPath = [SPUtils absolutePathToFile:path withScaleFactor:1.0f];
    if (!fullPath) [NSException raise:SPExceptionFileNotFound format:@"file %@ not found", path];
    
    NSString *error = nil;
    
    AudioFileID fileID = 0;
    void *soundBuffer = NULL;
    int   soundSize = 0;
    int   soundChannels = 0;
    int   soundFrequency = 0;
    double soundDuration = 0.0;
    
    do
    {        
        OSStatus result = noErr;        
        
        result = AudioFileOpenURL((CFURLRef)[NSURL fileURLWithPath:fullPath],
                                  kAudioFileReadPermission, 0, &fileID);
        if (result != noErr)
        {
            error = [NSString stringWithFormat:@"could not read audio file (%x)", (int)result];
            break;
        }
        
        AudioStreamBasicDescription fileFormat;
        UInt32 propertySize = (UInt32)sizeof(fileFormat);
        result = AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &propertySize, &fileFormat);
        if (result != noErr)
        {
            error = [NSString stringWithFormat:@"could not read file format info (%x)", (int)result];
            break;
        }
        
        propertySize = sizeof(soundDuration);
        result = AudioFileGetProperty(fileID, kAudioFilePropertyEstimatedDuration, 
                                      &propertySize, &soundDuration);
        if (result != noErr)
        {
            error = [NSString stringWithFormat:@"could not read sound duration (%x)", (int)result];
            break;
        }  
        
        if (fileFormat.mFormatID != kAudioFormatLinearPCM)
        { 
            error = @"sound file not linear PCM";
            break;
        }
        
        if (fileFormat.mChannelsPerFrame > 2)
        { 
            error = @"more than two channels in sound file";
            break;
        }
        
        if (!TestAudioFormatNativeEndian(fileFormat))
        {
            error = @"sounds must be little-endian";
            break;
        }
        
        if (!(fileFormat.mBitsPerChannel == 8 || fileFormat.mBitsPerChannel == 16))
        { 
            error = @"only files with 8 or 16 bits per channel supported";
            break;
        }
        
        UInt64 fileSize = 0;
        propertySize = sizeof(fileSize);
        result = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataByteCount, 
                                      &propertySize, &fileSize);
        if (result != noErr)
        {
            error = [NSString stringWithFormat:@"could not read sound file size (%x)", (int)result];
            break;
        }          
        
        UInt32 dataSize = (UInt32)fileSize;
        soundBuffer = malloc(dataSize);
        if (!soundBuffer)
        {
            error = @"could not allocate memory for sound data";
            break;
        }
        
        result = AudioFileReadBytes(fileID, false, 0, &dataSize, soundBuffer);
        if (result == noErr)
        {
            soundSize = (int)dataSize;
            soundChannels = fileFormat.mChannelsPerFrame;
            soundFrequency = fileFormat.mSampleRate;
        }
        else
        { 
            error = [NSString stringWithFormat:@"could not read sound data (%x)", (int)result];
            break;
        }
    }
    while (NO);
    
    if (fileID) AudioFileClose(fileID);
    
    if (!error)
    {   
        self = [[SPALSound alloc] initWithData:soundBuffer size:soundSize channels:soundChannels
                                     frequency:soundFrequency duration:soundDuration];            
    }
    else
    {
        NSLog(@"Sound '%@' will be played with AVAudioPlayer [Reason: %@]", path, error);
        self = [[SPAVSound alloc] initWithContentsOfFile:fullPath duration:soundDuration];
    }
    
    free(soundBuffer);    
    return self;
}

- (void)dealloc
{
    [_playingChannels release];
    [super dealloc];
}

- (void)play
{
    SPSoundChannel *channel = [self createChannel];
    [channel addEventListener:@selector(onSoundCompleted:) atObject:self
                      forType:SPEventTypeCompleted];
    [channel play];
    
    if (!_playingChannels) _playingChannels = [[NSMutableSet alloc] init];    
    [_playingChannels addObject:channel];
}

- (void)onSoundCompleted:(SPEvent *)event
{
    SPSoundChannel *channel = (SPSoundChannel *)event.target;
    [channel stop];
    [_playingChannels removeObject:channel];
}

- (SPSoundChannel *)createChannel
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'createChannel' in subclasses."];
    return nil;
}

- (double)duration
{
    [NSException raise:SPExceptionAbstractMethod format:@"Override 'duration' in subclasses."];
    return 0.0;
}

+ (instancetype)soundWithContentsOfFile:(NSString *)path
{
    return [[[SPSound alloc] initWithContentsOfFile:path] autorelease];
}


@end
