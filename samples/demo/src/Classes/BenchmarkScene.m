//
//  BenchmarkScene.m
//  Demo
//
//  Created by Daniel Sperl on 18.09.09.
//  Copyright 2011 Gamua. All rights reserved.
//

#import "BenchmarkScene.h"
#import <QuartzCore/QuartzCore.h> // for CACurrentMediaTime()

@interface BenchmarkScene ()

- (void)addTestObjects;
- (void)benchmarkComplete;

@end

#define WAIT_TIME 0.1f

@implementation BenchmarkScene
{
    SPButton *_startButton;
    SPTextField *_resultText;
    SPTexture *_texture;
    
    SPSprite *_container;
    int _frameCount;
    double _elapsed;
    BOOL _started;
    int _failCount;
    int _waitFrames;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        _texture = [[SPTexture alloc] initWithContentsOfFile:@"benchmark_object.png"];
        
        // the container will hold all test objects
        _container = [[SPSprite alloc] init];
        _container.touchable = NO; // we do not need touch events on the test objects -- thus, 
                                   // it is more efficient to disable them.
        [self addChild:_container atIndex:0];        
        
        SPTexture *buttonTexture = [SPTexture textureWithContentsOfFile:@"button_normal.png"];
        
        // we create a button that is used to start the benchmark.
        _startButton = [[SPButton alloc] initWithUpState:buttonTexture
                                                    text:@"Start benchmark"];
        [_startButton addEventListener:@selector(onStartButtonPressed:) atObject:self
                               forType:SPEventTypeTriggered];
        _startButton.x = 160 - (int)(_startButton.width / 2);
        _startButton.y = 20;
        [self addChild:_startButton];
        
        _started = NO;
        
        [self addEventListener:@selector(onEnterFrame:) atObject:self forType:SPEventTypeEnterFrame];
    }
    return self;    
}

- (void)onEnterFrame:(SPEnterFrameEvent *)event
{    
    if (!_started) return;
    
    _elapsed += event.passedTime;
    ++_frameCount;
    
    if (_frameCount % _waitFrames == 0)
    {
        float targetFPS = Sparrow.currentController.framesPerSecond;
        float realFPS = _waitFrames / _elapsed;
        
        if (ceilf(realFPS) >= targetFPS)
        {
            _failCount = 0;
            [self addTestObjects];
        }
        else
        {
            ++_failCount;
            
            if (_failCount > 15)
                _waitFrames = 5; // slow down creation process to be more exact
            if (_failCount > 20)
                _waitFrames = 10;
            if (_failCount == 25)
                [self benchmarkComplete]; // target fps not reached for a while
        }
        
        _elapsed = _frameCount = 0;
    }
    
    for (SPDisplayObject *child in _container)    
        child.rotation += 0.05f;    
}

- (void)onStartButtonPressed:(SPEvent*)event
{
    NSLog(@"starting benchmark");
    
    _startButton.visible = NO;
    _started = YES;
    _failCount = 0;
    _waitFrames = 3;
    
    [_resultText removeFromParent];
    _resultText = nil;
    
    _frameCount = 0;
    [self addTestObjects];
}

- (void)benchmarkComplete
{
    _started = NO;
    _startButton.visible = YES;
    
    int frameRate = (int)Sparrow.currentController.framesPerSecond;
    
    NSLog(@"benchmark complete!");
    NSLog(@"fps: %d", frameRate);
    NSLog(@"number of objects: %d", _container.numChildren);
    
    NSString *resultString = [NSString stringWithFormat:@"Result:\n%d objects\nwith %d fps", 
                              _container.numChildren, frameRate];
    
    _resultText = [SPTextField textFieldWithWidth:250 height:200 text:resultString];
    _resultText.fontSize = 30;
    _resultText.color = 0x0;
    _resultText.x = (320 - _resultText.width) / 2;
    _resultText.y = (480 - _resultText.height) / 2;
    
    [self addChild:_resultText];
    [_container removeAllChildren];
}

- (void)addTestObjects
{
    int border = 15;
    int numObjects = _failCount > 20 ? 2 : 5;
    
    for (int i=0; i<numObjects; ++i)
    {   
        SPImage *egg = [[SPImage alloc] initWithTexture:_texture];
        egg.x = [SPUtils randomIntBetweenMin:border andMax:GAME_WIDTH  - border];
        egg.y = [SPUtils randomIntBetweenMin:border andMax:GAME_HEIGHT - border];
        [_container addChild:egg];
    }
}

- (void)dealloc
{
    [self removeEventListenersAtObject:self forType:SPEventTypeEnterFrame];
    [_startButton removeEventListenersAtObject:self forType:SPEventTypeTriggered];
}

@end
