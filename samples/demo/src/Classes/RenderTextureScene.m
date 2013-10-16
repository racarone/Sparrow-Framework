//
//  RenderTextureScene.m
//  Demo
//
//  Created by Daniel Sperl on 05.12.10.
//  Copyright 2011 Gamua. All rights reserved.
//

#import "RenderTextureScene.h"

#define screenH 480

@interface RenderTextureScene ()

- (void)setupScene;

@end

@implementation RenderTextureScene
{
    SPRenderTexture *_renderTexture;
    SPImage *_brush;
    SPButton *_button;
    NSMutableDictionary *_colors;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        [self setupScene];        
    }
    return self;
}

- (void)setupScene
{
    _colors = [[NSMutableDictionary alloc] init];
    
    // we load the "brush" image from disk
    _brush = [[SPImage alloc] initWithContentsOfFile:@"brush.png"];
    _brush.pivotX = (int)(_brush.width / 2);
    _brush.pivotY = (int)(_brush.height / 2);
    _brush.blendMode = SP_BLEND_MODE_NORMAL;
    
    // the render texture is a dyanmic texture. We will draw the egg on that texture on
    // every touch event.
    _renderTexture = [[SPRenderTexture alloc] initWithWidth:320 height:435];
    
    // the canvas image will display the render texture
    SPImage *canvas = [SPImage imageWithTexture:_renderTexture];
    [canvas addEventListener:@selector(onTouch:) atObject:self forType:SPEventTypeTouch];
    [self addChild:canvas];
    
    // we draw a text into that canvas
    NSString *description = @"Touch the screen\nto draw!";
    SPTextField *infoText = [SPTextField textFieldWithWidth:256 height:128
                                                       text:description fontName:@"Verdana"
                                                   fontSize:24 color:0x0];
    infoText.x = CENTER_X - infoText.width / 2;
    infoText.y = CENTER_Y - infoText.height / 2;
    [_renderTexture drawObject:infoText];
    
    // add a button to let the user switch between "draw" and "erase" mode
    SPTexture *buttonTexture = [[SPTexture alloc] initWithContentsOfFile:@"button_normal.png"];
    _button = [[SPButton alloc] initWithUpState:buttonTexture text:@"Mode: Draw"];
    _button.x = (int)(CENTER_X - _button.width / 2);
    _button.y = 15;
    [_button addEventListener:@selector(onButtonTriggered:) atObject:self
                      forType:SPEventTypeTriggered];
    [self addChild:_button];
}

- (void)onButtonTriggered:(SPEvent *)event
{
    if (_brush.blendMode == SP_BLEND_MODE_NORMAL)
    {
        _brush.blendMode = SP_BLEND_MODE_ERASE;
        _button.text = @"Mode: Erase";
    }
    else
    {
        _brush.blendMode = SP_BLEND_MODE_NORMAL;
        _button.text = @"Mode: Draw";
    }
}

- (void)onTouch:(SPTouchEvent *)event
{
    NSSet *allTouches = [event touchesWithTarget:self];
    
    [_renderTexture drawBundled:^
    {
        for (SPTouch* touch in allTouches)
        {
            NSNumber *touchID = @((uint)touch);
            
            // don't draw on 'finger up'
            if (touch.phase == SPTouchPhaseEnded)
            {
                [_colors removeObjectForKey:touchID];
                continue;
            }
            
            if (touch.phase == SPTouchPhaseBegan)
                _colors[touchID] = @([SPUtils randomIntBetweenMin:0 andMax:0xffffff]);
            
            // find out location of touch event
            SPPoint *currentLocation = [touch locationInSpace:self];
            
            // center brush over location
            _brush.x = currentLocation.x;
            _brush.y = currentLocation.y;
            _brush.color = [_colors[touchID] intValue];
            _brush.rotation = [SPUtils randomFloat] * TWO_PI;
            
            // draw brush to render texture
            [_renderTexture drawObject:_brush];
        }
    }];
}

@end
