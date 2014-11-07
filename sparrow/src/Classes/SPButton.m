//
//  SPButton.m
//  Sparrow
//
//  Created by Daniel Sperl on 13.07.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPButton.h"
#import "SPGLTexture.h"
#import "SPImage.h"
#import "SPRectangle.h"
#import "SPSprite.h"
#import "SPStage.h"
#import "SPTextField.h"
#import "SPTexture.h"
#import "SPTouchEvent.h"

#define MAX_DRAG_DIST 40

// --- class implementation ------------------------------------------------------------------------

@implementation SPButton
{
    SPTexture *_upState;
    SPTexture *_downState;
    SPTexture *_overState;
    SPTexture *_disabledState;
    
    SPSprite *_contents;
    SPImage *_body;
    SPTextField *_textField;
    SPRectangle *_textBounds;
    SPSprite *_overlay;
    
    float _scaleWhenDown;
    float _alphaWhenDisabled;
    BOOL _enabled;
    SPButtonState _state;
}

#pragma mark Initialization

- (instancetype)initWithUpState:(SPTexture *)upState downState:(SPTexture *)downState
                      overState:(SPTexture *)overState disabledState:(SPTexture *)disabledState
{
    if (!upState)
        [NSException raise:SPExceptionInvalidOperation format:@"up state cannot be nil"];

    if ((self = [super init]))
    {
        _upState = [upState retain];
        _downState = [downState retain];
        _overState = [overState retain];
        _disabledState = [disabledState retain];

        _state = SPButtonStateUp;
        _body = [[SPImage alloc] initWithTexture:upState];
        _textField = nil;
        _scaleWhenDown = _downState ? 1.0 : 0.9;
        _alphaWhenDisabled = _disabledState ? 1.0 : 0.5;
        _enabled = YES;
        _textBounds = [[SPRectangle alloc] initWithX:0 y:0 width:_upState.width height:_upState.height];

        _contents = [[SPSprite alloc] init];
        [_contents addChild:_body];
        [self addChild:_contents];
        [self addEventListener:@selector(onTouch:) atObject:self forType:SPEventTypeTouch];

        self.touchGroup = YES;
    }
    return self;
}

- (instancetype)initWithUpState:(SPTexture *)upState downState:(SPTexture *)downState
{
    return [self initWithUpState:upState downState:downState overState:nil disabledState:nil];
}

- (instancetype)initWithUpState:(SPTexture *)upState text:(NSString *)text
{
    self = [self initWithUpState:upState];
    self.text = text;
    return self;
}

- (instancetype)initWithUpState:(SPTexture *)upState
{
    return [self initWithUpState:upState downState:nil];
}

- (instancetype)init
{
    SPTexture *texture = [[[SPGLTexture alloc] init] autorelease];
    return [self initWithUpState:texture];   
}

- (void)dealloc
{
    [self removeEventListenersAtObject:self forType:SPEventTypeTouch];

    [_upState release];
    [_downState release];
    [_overState release];
    [_disabledState release];
    [_overlay release];
    [_contents release];
    [_body release];
    [_textField release];
    [_textBounds release];

    [super dealloc];
}

+ (instancetype)buttonWithUpState:(SPTexture *)upState downState:(SPTexture *)downState
{
    return [[[self alloc] initWithUpState:upState downState:downState] autorelease];
}

+ (instancetype)buttonWithUpState:(SPTexture *)upState text:(NSString *)text
{
    return [[[self alloc] initWithUpState:upState text:text] autorelease];
}

+ (instancetype)buttonWithUpState:(SPTexture *)upState
{
    return [[[self alloc] initWithUpState:upState] autorelease];
}

#pragma mark Methods

- (void)readjustSize:(BOOL)resetTextBounds
{
    [_body readjustSize];

    if (resetTextBounds && _textField)
    {
        SPRectangle* bounds = [SPRectangle rectangleWithX:0 y:0 width:_body.width height:_body.height];
        SP_RELEASE_AND_RETAIN(_textBounds, bounds);
    }
}

#pragma mark SPDisplayObject

- (void)setWidth:(float)width
{
    // a button behaves just like a textfield: when changing width & height,
    // the textfield is not stretched, but will have more room for its chars.

    _body.width = width;
    [self createTextField];
}

- (float)width
{
    return _body.width;
}

- (void)setHeight:(float)height
{
    _body.height = height;
    [self createTextField];
}

- (float)height
{
    return _body.height;
}

#pragma mark Properties

- (void)setState:(SPButtonState)state
{
    _state = state;
    _contents.scaleX = _contents.scaleY = 1.0f;

    switch (state)
    {
        case SPButtonStateDown:
            [self setStateTexture:_downState];
            _contents.scaleX = _contents.scaleY = _scaleWhenDown;
            _contents.x = (1.0f - _scaleWhenDown) / 2.0f * _body.width;
            _contents.y = (1.0f - _scaleWhenDown) / 2.0f * _body.height;
            break;

        case SPButtonStateUp:
            [self setStateTexture:_upState];
            _contents.x = _contents.y = 0.0f;
            break;

        case SPButtonStateOver:
            [self setStateTexture:_overState];
            _contents.x = _contents.y = 0.0f;
            break;

        case SPButtonStateDisabled:
            [self setStateTexture:_disabledState];
            _contents.x = _contents.y = 0.0f;
            break;

        default:
            [NSException raise:SPExceptionInvalidOperation format:@"invalid button state"];
    }
}

- (void)setEnabled:(BOOL)value
{
    if (_enabled != value)
    {
        _enabled = value;
        _contents.alpha = value ? 1.0f : _alphaWhenDisabled;
        self.state = value ? SPButtonStateUp : SPButtonStateDisabled;
    }
}

- (NSString *)text
{
    if (_textField) return _textField.text;
    else return @"";
}

- (void)setText:(NSString *)value
{
    if (value.length == 0)
    {
        [_textField removeFromParent];
    }
    else
    {
        [self createTextField];
        if (!_textField.parent) [_contents addChild:_textField];
    }
    
    _textField.text = value;
}

- (NSString *)fontName
{
    if (_textField) return _textField.fontName;
    else return SPDefaultFontName;
}

- (void)setFontName:(NSString *)value
{
    [self createTextField];
    _textField.fontName = value;
}

- (float)fontSize
{
    if (_textField) return _textField.fontSize;
    else return SPDefaultFontSize;
}

- (void)setFontSize:(float)value
{
    [self createTextField];
    _textField.fontSize = value;
}

- (uint)fontColor
{
    if (_textField) return _textField.color;
    else return SPDefaultFontColor;
}

- (void)setFontColor:(uint)value
{
    [self createTextField];
    _textField.color = value;
}

- (SPHAlign)textHAlign
{
    return _textField ? _textField.hAlign : SPHAlignCenter;
}

- (void)setTextHAlign:(SPHAlign)textHAlign
{
    [self createTextField];
    _textField.hAlign = textHAlign;
}

- (SPVAlign)textVAlign
{
    return _textField ? _textField.vAlign : SPVAlignCenter;
}

- (void)setTextVAlign:(SPVAlign)textVAlign
{
    [self createTextField];
    _textField.vAlign = textVAlign;
}

- (uint)color
{
    return _body.color;
}

- (void)setColor:(uint)color
{
    _body.color = color;
}

- (void)setUpState:(SPTexture *)upState
{
    if (upState != _upState)
    {
        SP_RELEASE_AND_RETAIN(_upState, upState);
        if (_state == SPButtonStateUp) [self setStateTexture:_upState];
    }
}

- (void)setDownState:(SPTexture *)downState
{
    if (downState != _downState)
    {
        SP_RELEASE_AND_RETAIN(_downState, downState);
        if (_state == SPButtonStateDown) [self setStateTexture:_downState];
    }
}

- (void)setOverState:(SPTexture *)overState
{
    if (overState != _overState)
    {
        SP_RELEASE_AND_RETAIN(_overState, overState);
        if (_state == SPButtonStateOver) [self setStateTexture:_overState];
    }
}

- (void)setDisabledState:(SPTexture *)disabledState
{
    if (disabledState != _disabledState)
    {
        SP_RELEASE_AND_RETAIN(_disabledState, disabledState);
        if (_state == SPButtonStateDisabled) [self setStateTexture:_disabledState];
    }
}

- (void)setTextBounds:(SPRectangle *)value
{
    float scaleX = _body.scaleX;
    float scaleY = _body.scaleY;

    [_textBounds release];
    _textBounds = [[SPRectangle alloc] initWithX:value.x/scaleX y:value.y/scaleY 
                                           width:value.width/scaleX height:value.height/scaleY];
    
    [self createTextField];
}

- (SPRectangle *)textBounds
{
    float scaleX = _body.scaleX;
    float scaleY = _body.scaleY;
    
    return [SPRectangle rectangleWithX:_textBounds.x*scaleX y:_textBounds.y*scaleY 
                                 width:_textBounds.width*scaleX height:_textBounds.height*scaleY];
}

- (SPSprite *)overlay
{
    if (!_overlay)
        _overlay = [[SPSprite alloc] init];

    [_contents addChild:_overlay]; // make sure it's always on top
    return _overlay;
}

#pragma mark Events

- (void)onTouch:(SPTouchEvent *)touchEvent
{
    if (!_enabled) return;
    SPTouch *touch = [touchEvent touchWithTarget:self];

    if (!touch)
        self.state = SPButtonStateUp;
    else if (touch.phase == SPTouchPhaseHover)
        self.state = SPButtonStateOver;
    else if (touch.phase == SPTouchPhaseBegan && _state != SPButtonStateDown)
        self.state = SPButtonStateDown;
    else if (touch.phase == SPTouchPhaseMoved && _state == SPButtonStateDown)
    {
        // reset button when user dragged too far away after pushing
        SPRectangle *buttonRect = [self boundsInSpace:self.stage];
        if (touch.globalX < buttonRect.x - MAX_DRAG_DIST ||
            touch.globalY < buttonRect.y - MAX_DRAG_DIST ||
            touch.globalX > buttonRect.x + buttonRect.width + MAX_DRAG_DIST ||
            touch.globalY > buttonRect.y + buttonRect.height + MAX_DRAG_DIST)
        {
            self.state = SPButtonStateUp;
        }
    }
    else if (touch.phase == SPTouchPhaseEnded && _state == SPButtonStateDown)
    {
        self.state = SPButtonStateUp;
        [self dispatchEventWithType:SPEventTypeTriggered bubbles:YES];
    }
    else if (touch.phase == SPTouchPhaseCancelled && _state == SPButtonStateDown)
        self.state = SPButtonStateUp;
}

#pragma mark Private

- (void)setStateTexture:(SPTexture *)texture
{
    _body.texture = texture ?: _upState;
}

- (void)createTextField
{
    if (!_textField)
    {
        _textField = [[SPTextField alloc] init];
        _textField.vAlign = SPVAlignCenter;
        _textField.hAlign = SPHAlignCenter;
        _textField.touchable = NO;
        _textField.autoScale = YES;
    }

    _textField.width  = _textBounds.width;
    _textField.height = _textBounds.height;
    _textField.x = _textBounds.x;
    _textField.y = _textBounds.y;
}

@end
