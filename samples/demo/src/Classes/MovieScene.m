//
//  MovieScene.m
//  Demo
//
//  Created by Daniel Sperl on 14.05.10.
//  Copyright 2011 Gamua. All rights reserved.
//

#import "MovieScene.h"

@implementation MovieScene
{
    SPMovieClip *_movie;
}

- (instancetype)init
{
    if ((self = [super init])) 
    {
        NSString *description = @"[Animation provided by angryanimator.com]";        
        SPTextField *infoText = [SPTextField textFieldWithWidth:300 height:30 
                                                           text:description fontName:@"Verdana" 
                                                       fontSize:13 color:0x0];    
        infoText.x = infoText.y = 10;
        infoText.vAlign = SPVAlignTop;
        infoText.hAlign = SPHAlignCenter;
        [self addChild:infoText];        
        
        // all our animation textures are in the atlas
        SPTextureAtlas *atlas = [SPTextureAtlas atlasWithContentsOfFile:@"atlas.xml"];
        
        // add frames to movie
        NSArray *frames = [atlas texturesStartingWith:@"walk_"];
        _movie = [[SPMovieClip alloc] initWithFrames:frames fps:12];
        
        // add sounds
        SPSound *stepSound = [[SPSound alloc] initWithContentsOfFile:@"step.caf"];        
        [_movie setSound:[stepSound createChannel] atIndex:1];
        [_movie setSound:[stepSound createChannel] atIndex:7];
        
        // move the clip to the center and add it to the stage
        _movie.x = CENTER_X - (int)_movie.width / 2;
        _movie.y = CENTER_Y - (int)_movie.height / 2; 
        [self addChild:_movie];                

        // like any animation, the movie needs to be added to the juggler!
        // this is the recommended way to do that.
        [self addEventListener:@selector(onAddedToStage:) atObject:self forType:SPEventTypeAddedToStage];
        [self addEventListener:@selector(onRemovedFromStage:) atObject:self forType:SPEventTypeRemovedFromStage];
    }
    return self;
}

- (void)onAddedToStage:(SPEvent *)event
{
    [Sparrow.juggler addObject:_movie];
}

- (void)onRemovedFromStage:(SPEvent *)event
{
    [Sparrow.juggler removeObject:_movie];
}

@end
