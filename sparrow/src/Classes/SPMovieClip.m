//
//  SPMovieClip.m
//  Sparrow
//
//  Created by Daniel Sperl on 01.05.10.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPMacros.h"
#import "SPMovieClip.h"
#import "SPSoundChannel.h"

@implementation SPMovieClip
{
    NSMutableArray *_textures;
    NSMutableArray *_sounds;
    NSMutableArray *_durations;
    
    double _defaultFrameDuration;
    double _totalTime;
    double _currentTime;
    BOOL _loop;
    BOOL _playing;
    BOOL _muted;
    NSInteger _currentFrame;
}

#pragma mark Initialization

- (instancetype)initWithFrame:(SPTexture *)texture fps:(float)fps
{
    if ((self = [super initWithTexture:texture]))
    {
        _defaultFrameDuration = 1.0f / fps;
        _loop = YES;
        _playing = YES;
        _totalTime = 0.0;
        _currentTime = 0.0;
        _currentFrame = 0;
        _textures = [[NSMutableArray alloc] init];
        _sounds = [[NSMutableArray alloc] init];
        _durations = [[NSMutableArray alloc] init];        
        [self addFrameWithTexture:texture];
    }
    return self;
}

- (instancetype)initWithFrames:(NSArray<SPTexture*> *)textures fps:(float)fps
{
    if (textures.count == 0)
        [NSException raise:SPExceptionInvalidOperation format:@"empty texture array"];
        
    self = [self initWithFrame:textures[0] fps:fps];
        
    if (self && textures.count > 1)
        for (NSInteger i=1; i<textures.count; ++i)
            [self addFrameWithTexture:textures[i] atIndex:i];
    
    return self;
}

- (instancetype)initWithTexture:(SPTexture *)texture
{
    return [self initWithFrame:texture fps:10];
}

- (void)dealloc
{
    [_textures release];
    [_sounds release];
    [_durations release];
    [super dealloc];
}

+ (instancetype)movieWithFrame:(SPTexture *)texture fps:(float)fps
{
    return [[[self alloc] initWithFrame:texture fps:fps] autorelease];
}

+ (instancetype)movieWithFrames:(NSArray<SPTexture*> *)textures fps:(float)fps
{
    return [[[self alloc] initWithFrames:textures fps:fps] autorelease];
}

#pragma mark Frame Manipulation Methods

- (void)addFrameWithTexture:(SPTexture *)texture
{
    [self addFrameWithTexture:texture atIndex:self.numFrames];
}

- (void)addFrameWithTexture:(SPTexture *)texture duration:(double)duration
{
    [self addFrameWithTexture:texture duration:duration atIndex:self.numFrames];
}

- (void)addFrameWithTexture:(SPTexture *)texture duration:(double)duration sound:(SPSoundChannel *)sound
{
    [self addFrameWithTexture:texture duration:duration sound:sound atIndex:self.numFrames];
}

- (void)addFrameWithTexture:(SPTexture *)texture atIndex:(NSInteger)frameID
{
    [self addFrameWithTexture:texture duration:_defaultFrameDuration atIndex:frameID];
}

- (void)addFrameWithTexture:(SPTexture *)texture duration:(double)duration atIndex:(NSInteger)frameID
{
    [self addFrameWithTexture:texture duration:duration sound:nil atIndex:frameID];
}

- (void)addFrameWithTexture:(SPTexture *)texture duration:(double)duration
                      sound:(SPSoundChannel *)sound atIndex:(NSInteger)frameID
{
    _totalTime += duration;
    [_textures insertObject:texture atIndex:frameID];
    [_durations insertObject:@(duration) atIndex:frameID];
    [_sounds insertObject:(sound ? sound : [NSNull null]) atIndex:frameID];
}

- (void)removeFrameAtIndex:(NSInteger)frameID
{
    _totalTime -= [self durationAtIndex:frameID];
    [_textures removeObjectAtIndex:frameID];
    [_durations removeObjectAtIndex:frameID];
    [_sounds removeObjectAtIndex:frameID];
}

- (void)setTexture:(SPTexture *)texture atIndex:(NSInteger)frameID
{
    _textures[frameID] = texture;
}

- (void)setSound:(SPSoundChannel *)sound atIndex:(NSInteger)frameID
{
    _sounds[frameID] = sound ? sound : [NSNull null];
}

- (void)setDuration:(double)duration atIndex:(NSInteger)frameID
{
    _totalTime -= [self durationAtIndex:frameID];
    _durations[frameID] = @(duration);
    _totalTime += duration;
}

- (SPTexture *)textureAtIndex:(NSInteger)frameID
{
    return _textures[frameID];    
}

- (SPSoundChannel *)soundAtIndex:(NSInteger)frameID
{
    id sound = _sounds[frameID];
    if ([NSNull class] != [sound class]) return sound;
    else return nil;
}

- (double)durationAtIndex:(NSInteger)frameID
{
    return [_durations[frameID] doubleValue];
}

- (void)reverseFrames
{
    SP_RELEASE_AND_RETAIN(_textures, [[[[_textures reverseObjectEnumerator] allObjects] mutableCopy] autorelease]);
    SP_RELEASE_AND_RETAIN(_sounds, [[[[_textures reverseObjectEnumerator] allObjects] mutableCopy] autorelease]);
    SP_RELEASE_AND_RETAIN(_durations, [[[[_textures reverseObjectEnumerator] allObjects] mutableCopy] autorelease]);
    
    _currentTime = _totalTime - _currentTime;
    _currentFrame = self.numFrames - _currentFrame - 1;
}

#pragma mark Playback Methods

- (void)play
{
    _playing = YES;    
}

- (void)pause
{
    _playing = NO;
}

- (void)stop
{
    _playing = NO;
    self.currentFrame = 0;
}

#pragma mark SPAnimatable

- (void)advanceTime:(double)seconds
{    
    if (_loop && _currentTime == _totalTime) _currentTime = 0.0;    
    if (!_playing || seconds == 0.0 || _currentTime == _totalTime) return;    
    
    NSInteger i = 0;
    double durationSum = 0.0;
    double previousTime = _currentTime;
    double restTime = _totalTime - _currentTime;
    double carryOverTime = seconds > restTime ? seconds - restTime : 0.0;
    _currentTime = MIN(_totalTime, _currentTime + seconds);
    
    for (NSNumber *frameDuration in _durations)
    {
        double fd = [frameDuration doubleValue];
        if (durationSum + fd >= _currentTime)            
        {
            if (_currentFrame != i)
            {
                _currentFrame = i;
                [self updateCurrentFrame];
                [self playCurrentSound];
            }
            break;
        }
        
        ++i;
        durationSum += fd;
    }
    
    if (previousTime < _totalTime && _currentTime == _totalTime)
        [self dispatchEventWithType:SPEventTypeCompleted];
    
    [self advanceTime:carryOverTime];
}

#pragma mark Private

- (void)updateCurrentFrame
{
    self.texture = _textures[_currentFrame];
}

- (void)playCurrentSound
{
    if (_muted) return;
    id sound = _sounds[_currentFrame];
    if ([NSNull class] != [sound class])
        [sound play];
}

#pragma mark Properties

- (NSInteger)numFrames
{
    return _textures.count;
}

- (void)setCurrentFrame:(NSInteger)frameID
{
    _currentFrame = frameID;
    _currentTime = 0.0;
    
    for (NSInteger i=0; i<frameID; ++i)
        _currentTime += [_durations[i] doubleValue];
    
    [self updateCurrentFrame];
    if (_playing)
        [self playCurrentSound];
}

- (float)fps
{
	return (float)(1.0 / _defaultFrameDuration);
}

- (void)setFps:(float)fps
{
    float newFrameDuration = (fps == 0.0f ? INT_MAX : 1.0 / fps);
	float acceleration = newFrameDuration / _defaultFrameDuration;
    _currentTime *= acceleration;
    _defaultFrameDuration = newFrameDuration;

	for (NSInteger i=0; i<self.numFrames; ++i)
		[self setDuration:[self durationAtIndex:i] * acceleration atIndex:i];
}

- (BOOL)isPlaying
{
    if (_playing)
        return _loop || _currentTime < _totalTime;
    else
        return NO;
}

- (BOOL)isComplete
{
    return !_loop && _currentTime >= _totalTime;
}

@end
