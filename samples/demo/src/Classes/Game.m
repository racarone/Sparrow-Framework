//
//  Game.m
//  Sparrow
//
//  Created by Daniel Sperl on 16.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//

#import "Game.h"
#import "TextureScene.h"
#import "AsyncTextureScene.h"
#import "TouchScene.h"
#import "TextScene.h"
#import "AnimationScene.h"
#import "CustomHitTestScene.h"
#import "BenchmarkScene.h"
#import "MovieScene.h"
#import "SoundScene.h"
#import "RenderTextureScene.h"

@implementation Game
{
    Scene *_currentScene;
    SPSprite *_mainMenu;
    float _offsetY;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        // make simple adjustments for iPhone 5+ screens:
        _offsetY = (Sparrow.stage.height - 480) / 2;
        
        // add background image
        SPImage *background = [SPImage imageWithContentsOfFile:@"background.jpg"];
        background.y = _offsetY > 0.0f ? 0.0 : -44;
        background.blendMode = SP_BLEND_MODE_NONE;
        [self addChild:background];
        
        // this sprite will contain objects that are only visible in the main menu
        _mainMenu = [[SPSprite alloc] init];
        _mainMenu.y = _offsetY;
        [self addChild:_mainMenu];
        
        SPImage *logo = [SPImage imageWithContentsOfFile:@"logo.png"];
        logo.y = _offsetY + 5;
        [_mainMenu addChild:logo];
        
        // choose which scenes will be accessible
        NSArray *scenesToCreate = @[@"Textures", [TextureScene class],
                                    @"Async Textures", [AsyncTextureScene class],
                                    @"Multitouch", [TouchScene class],
                                    @"TextFields", [TextScene class],
                                    @"Animations", [AnimationScene class],
                                    @"Custom hit-test", [CustomHitTestScene class],
                                    @"Movie Clip", [MovieScene class],
                                    @"Sound", [SoundScene class],
                                    @"RenderTexture", [RenderTextureScene class],
                                    @"Benchmark", [BenchmarkScene class]];
        
        SPTexture *buttonTexture = [SPTexture textureWithContentsOfFile:@"button_big.png"];
        int count = 0;
        int index = 0;
        
        // create buttons for each scene
        while (index < scenesToCreate.count)
        {
            NSString *sceneTitle = scenesToCreate[index++];
            Class sceneClass = scenesToCreate[index++];
            
            SPButton *button = [SPButton buttonWithUpState:buttonTexture text:sceneTitle];
            button.x = count % 2 == 0 ? 28 : 167;
            button.y = _offsetY + 170 + (count / 2) * 52;
            button.name = NSStringFromClass(sceneClass);
            
            if (scenesToCreate.count % 2 != 0 && count % 2 == 1)
                button.y += 26;
            
            [button addEventListener:@selector(onButtonTriggered:) atObject:self 
                             forType:SPEventTypeTriggered];
            [_mainMenu addChild:button];
            ++count;
        }
        
        [self addEventListener:@selector(onSceneClosing:) atObject:self
                       forType:EventTypeSceneClosing];
        
    }
    return self;
}

- (void)onButtonTriggered:(SPEvent *)event
{
    if (_currentScene) return;
    
    // the class name of the scene is saved in the "name" property of the button. 
    SPButton *button = (SPButton *)event.target;
    Class sceneClass = NSClassFromString(button.name);
    
    // create an instance of that class and add it to the display tree.
    _currentScene = [[sceneClass alloc] init];
    _currentScene.y = _offsetY;
    _mainMenu.visible = NO;
    [self addChild:_currentScene];
}

- (void)onSceneClosing:(SPEvent *)event
{
    [_currentScene removeFromParent];
    _currentScene = nil;
    _mainMenu.visible = YES;
}

@end
