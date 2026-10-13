//
//  main.m
//  Easydict
//
//  Created by tisfeng on 2022/10/30.
//  Copyright © 2023 izual. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "EZWindowManager.h"
#import "XPMArguments.h"
#import "entry.h"
#include <stdio.h>
#include <sys/ioctl.h>

static void delay_block(dispatch_block_t block) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        block();
    });
}

void queryText(NSString *text) {
    // ???: need to wait AppDelegate loaded.
    delay_block(^{
        EZWindowManager *windowManager = [EZWindowManager shared];
        [windowManager showFloatingWindowType:EZWindowTypeFixed
                                    queryText:text.ns_trim
                                    autoQuery:YES
                                   actionType:EZActionTypeInvokeQuery];
    });
}

void parseArmguments(void) {
    parseApplicationArguments(NSProcessInfo.processInfo.arguments);
}

void parseApplicationArguments(NSArray<NSString *> *launchArguments) {
    XPMArgumentSignature *helpSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-h --help]"],
    *detectTextSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-d --detectText]="],
    *queryTextSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-q --queryText]="];
    
    NSArray *signatures = @[ helpSig, detectTextSig, queryTextSig ];
    
    XPMArgumentPackage *arguments = [[[XPMArgumentParser alloc] initWithArguments:launchArguments
                                                                    signatures:signatures] parse];
    
    bool print_help = false;
    
    if ([arguments booleanValueForSignature:helpSig]) {
        print_help = true;
    } else {
        NSString *query_text = [[arguments firstObjectForSignature:queryTextSig] description];
        if (query_text) {
            MMLogInfo(@"queryText: %@", query_text);
            queryText(query_text);
        }
        
        NSString *detect_text = [[arguments firstObjectForSignature:detectTextSig] description];
        if (detect_text) {
            MMLogInfo(@"detectText: %@", detect_text);
        }
        
        if (detect_text) {
            delay_block(^{
                [EZWindowManager.shared detectQueryText:detect_text completion:^(NSString * _Nonnull language) {
                    MMLogInfo(@"%s\n", [language UTF8String]);
                }];
            });
        }
    }
    
    if (print_help) {
        struct winsize ws;
        ioctl(0, TIOCGWINSZ, &ws);
        
        MMLogInfo(@"Example program:\n");
        MMLogInfo(@"  %s Query text\n", [[queryTextSig descriptionForHelpWithIndent:2 terminalWidth:(NSUInteger)ws.ws_col] UTF8String]);
    }
}
