//
//  FilterScene.m
//  Demo
//
//  Created by Daniel Sperl on 14.05.10.
//  Copyright 2011 Gamua. All rights reserved.
//

#import "FilterScene.h"

@implementation FilterScene
{
    SPButton *_button;
    SPTextField *_infoText;
    SPImage *_image;
    NSMutableArray *_filterInfos;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        SPTexture *buttonTexture = [SPTexture textureWithContentsOfFile:@"button_normal.png"];

        _button = [SPButton buttonWithUpState:buttonTexture text:@"Switch Filter"];
        [_button addEventListener:@selector(onButtonPressed:) atObject:self forType:SPEventTypeTriggered];
        _button.x = CENTER_X - (int)_button.width / 2;
        _button.y = 15;
        [self addChild:_button];

        _image = [SPImage imageWithContentsOfFile:@"sparrow_round.png"];
        _image.x = CENTER_X - (int)_image.width / 2;
        _image.y = 170;
        [self addChild:_image];

        _infoText = [SPTextField textFieldWithWidth:300 height:32 text:@"" fontName:@"Verdana" fontSize:19 color:0x0];
        _infoText.x = 10;
        _infoText.y = 330;
        [self addChild:_infoText];

        [self initFilters];
        [self onButtonPressed:nil];
    }
    return self;
}

- (void)onButtonPressed:(SPTouchEvent*)event
{
    NSString *text = _filterInfos[0];
    SPFragmentFilter *filter = _filterInfos[1];

    [_filterInfos removeObjectAtIndex:0];
    [_filterInfos removeObjectAtIndex:0];
    [_filterInfos addObject:text];
    [_filterInfos addObject:filter];

    _infoText.text = text;
    _image.filter = filter;
}

- (SPTexture*)createDisplacementFilterWithWidth:(float)width height:(float)height
{
    float scale = Sparrow.contentScaleFactor;
    CGSize size = CGSizeMake(width*scale, height*scale);

    SPPerlinNoise *noise = [SPPerlinNoise perlinNoiseWithOctaves:3 zoom:scale*25 persistence:0.5];
    UIImage *image = [UIImage noiseWithPerlinGenerator:noise size:size firstColor:[UIColor whiteColor] secondColor:[UIColor blackColor]];
    return [[SPTexture alloc] initWithContentsOfImage:image];
}

- (void)initFilters
{
    _filterInfos = [@[ @"Identity",    [SPColorMatrixFilter colorMatrixFilter],
                       @"Blur",        [SPBlurFilter blurFilter],
                       @"Drop Shadow", [SPBlurFilter dropShadow],
                       @"Glow",        [SPBlurFilter glow]] mutableCopy];

    SPTexture *displacementTexture = [self createDisplacementFilterWithWidth:_image.width height:_image.height];
    SPDisplacementMapFilter *displacementFilter = [[SPDisplacementMapFilter alloc] initWithMapTexture:displacementTexture];
    displacementFilter.componentX = SPColorChannelRed;
    displacementFilter.componentY = SPColorChannelGreen;
    displacementFilter.scaleX = 25;
    displacementFilter.scaleY = 25;
    [_filterInfos addObjectsFromArray:@[@"Displacement Map", displacementFilter]];

    SPColorMatrixFilter *invertFilter = [SPColorMatrixFilter colorMatrixFilter];
    [invertFilter invert];
    [_filterInfos addObjectsFromArray:@[@"Invert", invertFilter]];

    SPColorMatrixFilter *grayscaleFilter = [SPColorMatrixFilter colorMatrixFilter];
    [grayscaleFilter adjustSaturation:-1];
    [_filterInfos addObjectsFromArray:@[@"Grayscale", grayscaleFilter]];

    SPColorMatrixFilter *saturationFilter = [SPColorMatrixFilter colorMatrixFilter];
    [grayscaleFilter adjustSaturation:1];
    [_filterInfos addObjectsFromArray:@[@"Saturation", saturationFilter]];

    SPColorMatrixFilter *contrastFilter = [SPColorMatrixFilter colorMatrixFilter];
    [contrastFilter adjustContrast:0.75];
    [_filterInfos addObjectsFromArray:@[@"Contrast", contrastFilter]];

    SPColorMatrixFilter *brightnessFilter = [SPColorMatrixFilter colorMatrixFilter];
    [brightnessFilter adjustBrightness:-0.25];
    [_filterInfos addObjectsFromArray:@[@"Brightness", brightnessFilter]];

    SPColorMatrixFilter *hueFilter = [SPColorMatrixFilter colorMatrixFilter];
    [hueFilter adjustHue:1];
    [_filterInfos addObjectsFromArray:@[@"Hue", hueFilter]];
}

@end
