//
//  EZAudioButton.h
//  EasyRead
//
//  Created by tisfeng on 2023/4/23.
//  Copyright © 2023 izual. All rights reserved.
//

#import "EZHoverButton.h"
#import "EZAudioPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface EZAudioButton : EZHoverButton

@property (nonatomic, strong) EZAudioPlayer *audioPlayer;

@property (nonatomic, copy) void (^playAudioBlock)(void);

@property (nonatomic, copy) void (^playStatus)(BOOL isPlaying, EZAudioButton *audioButton);

@end

NS_ASSUME_NONNULL_END
