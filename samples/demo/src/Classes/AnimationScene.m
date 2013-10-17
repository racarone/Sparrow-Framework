//
//  TweenScene.m
//  Demo
//
//  Created by Daniel Sperl on 23.08.09.
//  Copyright 2011 Gamua. All rights reserved.
//

#import "AnimationScene.h"

@interface AnimationScene ()

- (void)setupScene;
- (void)resetEgg;
- (void)colorizeEgg:(BOOL)colorize;

@end

@implementation AnimationScene
{
    SPButton *_startButton;
    SPButton *_delayButton;
    SPImage *_egg;
    SPTextField *_transitionLabel;
    NSMutableArray *_transitions;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        // define some sample transitions for the animation demo. There are more available!
        _transitions = [[NSMutableArray alloc] initWithObjects:
                        SPTransitionLinear, SPTransitionEaseInOut, SPTransitionEaseOutBack,
                        SPTransitionEaseOutBounce, SPTransitionEaseOutElastic, nil];
        [self setupScene];
    }
    return self;
}

- (void)setupScene
{   
    SPTexture *buttonTexture = [SPTexture textureWithContentsOfFile:@"button_normal.png"];
    
    // we create a button that is used to start the tween.
    _startButton = [[SPButton alloc] initWithUpState:buttonTexture text:@"Start animation"];
    [_startButton addEventListener:@selector(onStartButtonPressed:) atObject:self
                           forType:SPEventTypeTriggered];
    _startButton.x = 160 - (int)_startButton.width / 2;
    _startButton.y = 20;
    [self addChild:_startButton];
    
    // this button will show you how to call a method with a delay
    _delayButton = [[SPButton alloc] initWithUpState:buttonTexture text:@"Delayed call"];
    [_delayButton addEventListener:@selector(onDelayButtonPressed:) atObject:self
                           forType:SPEventTypeTriggered];
    _delayButton.x = _startButton.x;
    _delayButton.y = _startButton.y + 40;    
    [self addChild:_delayButton];
    
    // the egg image will be tweened.
    _egg = [[SPImage alloc] initWithContentsOfFile:@"sparrow_front.png"];
    [self resetEgg];
    [self addChild:_egg];
    
    _transitionLabel = [[SPTextField alloc] initWithText:@""];
    _transitionLabel.color = 0x0;
    _transitionLabel.x = 0;
    _transitionLabel.y = _delayButton.y + 40;
    _transitionLabel.width = 320;
    _transitionLabel.height = 30;
    _transitionLabel.alpha = 0.0f; // invisible, will be shown later
    [self addChild:_transitionLabel];      
}

- (void)resetEgg
{
    _egg.x = 15;
    _egg.y = 100;
    _egg.scaleX = _egg.scaleY = 1.0f;
    _egg.rotation = 0.0f;
}

- (void)onStartButtonPressed:(SPEvent *)event
{
    _startButton.enabled = NO;
    [self resetEgg];
    
    // get next transition style from array and enqueue it at the end
    NSString *transition = _transitions[0];
    [_transitions removeObjectAtIndex:0];
    [_transitions addObject:transition];
    
    // to animate any numeric property of an arbitrary object (not just display objects!), you
    // can create a 'Tween'. One tween object animates one target for a certain time, with
    // a certain transition function.    
    SPTween *tween = [SPTween tweenWithTarget:_egg time:2.0f transition:transition];

    // you can animate any property as long as it's numeric (float, double, int). 
    // it is animated from it's current value to a target value.
    [tween moveToX:305 y:365];
    [tween scaleTo:0.5f];
    [tween animateProperty:@"rotation" targetValue:PI_HALF];
    
    tween.onComplete = ^{ _startButton.enabled = YES; };
    
    // the tween alone is useless -- once in every frame, it has to be advanced, so that the 
    // animation occurs. This is done by the 'Juggler'. It receives the tween and will use it to 
    // animate the object. 
    // There is a default juggler at the stage, but you can create your own jugglers, as well.
    // That way, you can group animations into logical parts.    
    [Sparrow.juggler addObject:tween];
    
    // show which tweening function is used
    _transitionLabel.text = transition;
    _transitionLabel.alpha = 1.0f;
    SPTween *hideTween = [SPTween tweenWithTarget:_transitionLabel time:2.0f
                                       transition:SPTransitionEaseIn];
    [hideTween animateProperty:@"alpha" targetValue:0.0f];
    [Sparrow.juggler addObject:hideTween];
}

- (void)onDelayButtonPressed:(SPEvent *)event
{
    _delayButton.enabled = NO;
    
    // Using the juggler, you can delay a method call.
    //
    // This is especially useful when used with your own juggler. Assume your game has one class
    // that handles the playing field. This class has its own juggler, and advances it in every 
    // frame. (By calling [myJuggler advanceTime:]).    
    // All animations and delayed calls (!) within the playing field are added to this 
    // juggler. Now, when the game is paused, all you have to do is *not* to advance this juggler.
    // Everything will be paused: animations as well as the delayed calls.
    //
    // the method [SPJuggler delayInvocationAtTarget:byTime:] returns a proxy object. Call
    // the method you would like to call on this proxy object instead of the real method target.
    // In this sample, [self colorizeEgg:] will be called after the specified delay.
    
    SPJuggler *juggler = Sparrow.juggler;
    
    [[juggler delayInvocationAtTarget:self byTime:1.0f] colorizeEgg:YES];
    [[juggler delayInvocationAtTarget:self byTime:2.0f] colorizeEgg:NO];
}

- (void)colorizeEgg:(BOOL)colorize
{
    if (colorize) _egg.color = 0xff3333; // 0xrrggbb
    else 
    {    
        _egg.color = 0xffffff; // white, the standard color of a quad
        _delayButton.enabled = YES;
    }
}

- (void)dealloc
{
    [_startButton removeEventListenersAtObject:self forType:SPEventTypeTriggered];
    [_delayButton removeEventListenersAtObject:self forType:SPEventTypeTriggered];
}

@end
