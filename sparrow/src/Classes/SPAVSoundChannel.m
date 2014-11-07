//
//  SPAVSoundChannel.m
//  Sparrow
//
//  Created by Daniel Sperl on 29.05.10.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPAudioEngine.h"
#import "SPAVSound.h"
#import "SPAVSoundChannel.h"

@implementation SPAVSoundChannel
{
    SPAVSound *_sound;
    AVAudioPlayer *_player;
    BOOL _paused;
    float _volume;
}

#pragma mark Initialization

- (instancetype)init
{
    [self release];
    return nil;
}

- (instancetype)initWithSound:(SPAVSound *)sound
{
    if ((self = [super init]))
    {
        _volume = 1.0f;
        _sound = [sound retain];
        _player = [[sound createPlayer] retain];
        _player.volume = [SPAudioEngine masterVolume];
        _player.delegate = self;                
        [_player prepareToPlay];

        [[NSNotificationCenter defaultCenter] addObserver:self 
            selector:@selector(onMasterVolumeChanged:)
                name:SPNotificationMasterVolumeChanged object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _player.delegate = nil;

    [_sound release];
    [_player release];
    [super dealloc];
}

#pragma mark SPSoundChannel

- (void)play
{
    _paused = NO;
    [_player play];
}

- (void)pause
{
    _paused = YES;
    [_player pause];
}

- (void)stop
{
    _paused = NO;
    [_player stop];
    _player.currentTime = 0;
}

- (BOOL)isPlaying
{
    return _player.playing;
}

- (BOOL)isPaused
{
    return _paused && !_player.playing;
}

- (BOOL)isStopped
{
    return !_paused && !_player.playing;
}

- (BOOL)loop
{
    return _player.numberOfLoops < 0;
}

- (void)setLoop:(BOOL)value
{
    _player.numberOfLoops = value ? -1 : 0;
}

- (float)volume
{
    return _volume;
}

- (void)setVolume:(float)value
{
    _volume = value;
    _player.volume = value * [SPAudioEngine masterVolume];
}

- (double)duration
{
    return _player.duration;
}

#pragma mark AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self dispatchEventWithType:SPEventTypeCompleted];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"Error during sound decoding: %@", [error description]);
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player
{
    [player pause];
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player
{
    [player play];
}

#pragma mark Notifications

- (void)onMasterVolumeChanged:(NSNotification *)notification
{
    self.volume = _volume;
}

@end
