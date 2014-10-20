//
//  Sparrow.h
//  Sparrow
//
//  Created by Daniel Sperl on 21.03.09.
//  Copyright 2011-2014 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Availability.h>

#ifndef __IPHONE_6_0
    #warning "This project uses features only available in iOS SDK 6.0 and later."
#endif

#define SPARROW_VERSION @"2.1"

#import <Sparrow/SparrowClass.h>
#import <Sparrow/SPAudioEngine.h>
#import <Sparrow/SPBaseEffect.h>
#import <Sparrow/SPBitmapFont.h>
#import <Sparrow/SPBlendMode.h>
#import <Sparrow/SPBlurFilter.h>
#import <Sparrow/SPButton.h>
#import <Sparrow/SPColorMatrix.h>
#import <Sparrow/SPColorMatrixFilter.h>
#import <Sparrow/SPContext.h>
#import <Sparrow/SPDelayedInvocation.h>
#import <Sparrow/SPDisplacementMapFilter.h>
#import <Sparrow/SPDisplayObject.h>
#import <Sparrow/SPDisplayObjectContainer.h>
#import <Sparrow/SPEnterFrameEvent.h>
#import <Sparrow/SPEvent.h>
#import <Sparrow/SPEventDispatcher.h>
#import <Sparrow/SPGLTexture.h>
#import <Sparrow/SPJuggler.h>
#import <Sparrow/SPImage.h>
#import <Sparrow/SPMacros.h>
#import <Sparrow/SPMatrix.h>
#import <Sparrow/SPMovieClip.h>
#import <Sparrow/SPNSExtensions.h>
#import <Sparrow/SPOpenGL.h>
#import <Sparrow/SPOverlayView.h>
#import <Sparrow/SPPoint.h>
#import <Sparrow/SPProgram.h>
#import <Sparrow/SPPVRData.h>
#import <Sparrow/SPQuad.h>
#import <Sparrow/SPQuadBatch.h>
#import <Sparrow/SPRectangle.h>
#import <Sparrow/SPRenderSupport.h>
#import <Sparrow/SPRenderTexture.h>
#import <Sparrow/SPResizeEvent.h>
#import <Sparrow/SPSound.h>
#import <Sparrow/SPSoundChannel.h>
#import <Sparrow/SPSprite.h>
#import <Sparrow/SPStage.h>
#import <Sparrow/SPSubTexture.h>
#import <Sparrow/SPTextField.h>
#import <Sparrow/SPTexture.h>
#import <Sparrow/SPTextureAtlas.h>
#import <Sparrow/SPTouchEvent.h>
#import <Sparrow/SPTransitions.h>
#import <Sparrow/SPTween.h>
#import <Sparrow/SPURLConnection.h>
#import <Sparrow/SPUtils.h>
#import <Sparrow/SPVertexData.h>
#import <Sparrow/SPViewController.h>
