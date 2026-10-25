//
//  NSImage+EZSymbolmage.h
//  EasyRead
//
//  Created by tisfeng on 2023/4/23.
//  Copyright © 2023 izual. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (EZSymbolmage)

+ (NSImage *)ez_imageWithSymbolName:(NSString *)name;

+ (NSImage *)ez_imageWithSymbolName:(NSString *)name size:(CGSize)size scale:(NSImageSymbolScale)scale;

@end

NS_ASSUME_NONNULL_END
