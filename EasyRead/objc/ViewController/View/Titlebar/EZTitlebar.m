//
//  EZTitlebar.m
//  Easydict
//
//  Created by tisfeng on 2022/11/19.
//  Copyright © 2022 izual. All rights reserved.
//

#import "EZTitlebar.h"
#import "EZTitleBarMoveView.h"
#import "NSObject+EZWindowType.h"
#import "NSImage+EZResize.h"
#import "NSImage+EZSymbolmage.h"
#import "NSObject+EZDarkMode.h"
#import "EZBaseQueryWindow.h"


typedef NS_ENUM(NSInteger, EZTitlebarButtonType) {
    EZTitlebarButtonTypePin = 0,
    EZTitlebarButtonTypeGoogle,
    EZTitlebarButtonTypeAppleDic,
    EZTitlebarButtonTypeEudicDic,
};

@interface EZTitlebar ()

@property (nonatomic, strong) NSStackView *stackView;
@property (nonatomic, strong) NSStackView *brandView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) EZOpenLinkButton *playButton;
@property (nonatomic, strong) EZOpenLinkButton *copyButton;
@property (nonatomic, strong) EZOpenLinkButton *settingsButton;
@property (nonatomic, strong) NSMenu *quickActionMenu;

@property (nonatomic, assign) CGSize buttonSize;
@property (nonatomic, assign) CGFloat buttonWidth;
@property (nonatomic, assign) CGFloat buttonPadding;

@property (nonatomic, assign) CGSize imageSize;
@property (nonatomic, assign) CGFloat imageWidth;

@end

@implementation EZTitlebar

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        [self setup];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setup {
    self.buttonWidth = 24;
    self.imageWidth = 20;
    self.buttonPadding = 4;
    
    self.buttonSize = CGSizeMake(self.buttonWidth, self.buttonWidth);
    self.imageSize = CGSizeMake(self.imageWidth, self.imageWidth);
    
    [self addSubview:self.brandView];
    [self addSubview:self.stackView];
    [self installToolbarButtons];

    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self selector:@selector(updateTitlebar) name:NSNotification.linkButtonUpdated object:nil];
    [defaultCenter addObserver:self selector:@selector(updateTitlebar) name:NSNotification.languagePreferenceChanged object:nil];
}

- (void)updateTitlebar {
    /**
     Fix appcenter issue, seems cannot remove self.subviews 🤔
     
     -[EZTitlebar updateConstraints]
     EZTitlebar.m, line 64
     SIGABRT: *** Collection <__NSArrayM: 0x6000036e45d0> was mutated while being enumerated.
     */
    
    // Remove and dealloc all views to refresh UI.
    
    [_pinButton removeFromSuperview];
    [_stackView removeFromSuperview];
    [_brandView removeFromSuperview];
    _stackView = nil;
    _brandView = nil;
    _titleLabel = nil;
    _quickActionButton = nil;
    _quickActionMenu = nil;

    [self updatePinButton];
    
    [self addSubview:self.brandView];
    [self addSubview:self.stackView];
    [self installToolbarButtons];
    
    [self setNeedsUpdateConstraints:YES];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self setNeedsUpdateConstraints:YES];
}

- (void)updateConstraints {
    CGFloat margin = EZHorizontalCellSpacing_10;
    BOOL isMainWindow = NO;
    if ([self.window isKindOfClass:[EZBaseQueryWindow class]]) {
        isMainWindow = ((EZBaseQueryWindow *)self.window).windowType == EZWindowTypeMain;
    }
    // Main windows still show the traffic lights in this bar.
    CGFloat leftInset = isMainWindow ? 78 : margin;

    [self.brandView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).offset(leftInset);
        make.centerY.equalTo(self);
        make.right.lessThanOrEqualTo(self.stackView.mas_left).offset(-8);
    }];

    [self.stackView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self);
        make.right.equalTo(self).offset(-margin);
    }];

    [super updateConstraints];
}

/// Right-to-left stack, so the first button sits at the trailing edge.
- (void)installToolbarButtons {
    for (NSView *view in self.stackView.arrangedSubviews.copy) {
        [self.stackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.stackView addArrangedSubview:self.settingsButton];
    [self.stackView addArrangedSubview:self.copyButton];
    [self.stackView addArrangedSubview:self.playButton];
    [self.stackView addArrangedSubview:self.pinButton];
    [self updateShortcutButtonsToolTip];
    self.menu = self.quickActionMenu;
}

#pragma mark - Public Methods

- (void)updateShortcutButtonsToolTip {
    self.pinButton.toolTip = [self toolTipStrWithButtonType:EZTitlebarButtonTypePin];
    self.playButton.toolTip = NSLocalizedString(@"selection.panel.speak_original", nil);
    self.copyButton.toolTip = NSLocalizedString(@"selection.panel.copy_original", nil);
    self.settingsButton.toolTip = NSLocalizedString(@"open_app_settings", nil);
    for (NSNumber *typeNumber in [self shortcutButtonTypes]) {
        EZTitlebarButtonType buttonType = typeNumber.integerValue;
        EZOpenLinkButton *button = [self buttonWithType:buttonType];
        button.toolTip = [self toolTipStrWithButtonType:buttonType];
    }
}


#pragma mark - Actions

- (void)replaceNewlineWithSpace {
    _menuActionBlock(EZTitlebarQuickActionReplaceNewlineWithSpace);
}

- (void)removeCodeCommentSymbols {
    _menuActionBlock(EZTitlebarQuickActionRemoveCommentBlockSymbols);
}

- (void)splitWords {
    _menuActionBlock(EZTitlebarQuickActionWordsSegmentation);
}

- (void)goToSettings {
    [[NSNotificationCenter defaultCenter] postNotificationName:EZOpenSettingsNotification object:nil];
}

- (void)openGoogleLink {
    [self.googleButton openLink];
}

- (void)openAppleDictionaryLink {
    [self.appleDictionaryButton openLink];
}

- (void)openEudicLink {
    [self.eudicButton openLink];
}

- (NSArray<NSDictionary *> *)externalLinkMenuItems {
    NSMutableArray *items = [NSMutableArray array];
    if (MyConfiguration.shared.showGoogleQuickLink) {
        [items addObject:@{
            @"title" : @"open_in_google",
            @"action" : NSStringFromSelector(@selector(openGoogleLink))
        }];
    }
    if (MyConfiguration.shared.showAppleDictionaryQuickLink) {
        [items addObject:@{
            @"title" : @"open_in_apple_dictionary",
            @"action" : NSStringFromSelector(@selector(openAppleDictionaryLink))
        }];
    }
    if (MyConfiguration.shared.showEudicQuickLink) {
        [items addObject:@{
            @"title" : @"open_in_eudic",
            @"action" : NSStringFromSelector(@selector(openEudicLink))
        }];
    }
    return items;
}

#pragma mark - Getter && Setter

- (EZOpenLinkButton *)pinButton {
    if (!_pinButton) {
        EZOpenLinkButton *pinButton = [[EZOpenLinkButton alloc] init];
        _pinButton = pinButton;
        
        pinButton.contentTintColor = [NSColor clearColor];
        pinButton.clickBlock = nil;
        self.pin = NO;
        
        mm_weakify(self);
        [pinButton setMouseDownBlock:^(EZButton *_Nonnull button) {
//            MMLogInfo(@"pin mouse down, state: %ld", button.buttonState);
            mm_strongify(self);
            self.pin = !self.pin;
        }];
        
        [pinButton setMouseUpBlock:^(EZButton *_Nonnull button) {
//            MMLogInfo(@"pin mouse up, state: %ld", button.buttonState);
            mm_strongify(self);
            BOOL oldPin = !self.pin;
            
            // This means clicked pin button.
            if (button.state == EZButtonHoverState) {
                self.pin = !oldPin;
            } else if (button.buttonState == EZButtonNormalState) {
                self.pin = oldPin;
            }
        }];

        [self executeOnAppearanceChange:^(EZTitlebar *titlebar, BOOL isDarkMode) {
            [titlebar updatePinButtonImage];
        }];
        [pinButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.size.mas_equalTo(self.buttonSize);
        }];
    }
    return _pinButton;
}

- (NSStackView *)brandView {
    if (!_brandView) {
        NSImageView *iconView = [[NSImageView alloc] init];
        iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
        NSImage *icon = [NSImage imageNamed:@"blue-white-icon"];
        if (!icon) {
            icon = NSApp.applicationIconImage;
        }
        if (!icon) {
            icon = [NSImage ez_imageWithSymbolName:@"character.book.closed"];
        }
        iconView.image = icon;
        iconView.wantsLayer = YES;
        iconView.layer.cornerRadius = 4;
        iconView.layer.masksToBounds = YES;
        [iconView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.height.mas_equalTo(16);
        }];

        NSTextField *titleLabel = [NSTextField labelWithString:NSLocalizedString(@"selection.panel.title", nil)];
        titleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        titleLabel.textColor = NSColor.labelColor;
        titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        titleLabel.maximumNumberOfLines = 1;
        [titleLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                             forOrientation:NSLayoutConstraintOrientationHorizontal];
        self.titleLabel = titleLabel;

        NSStackView *brand = [NSStackView stackViewWithViews:@[ iconView, titleLabel ]];
        brand.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        brand.alignment = NSLayoutAttributeCenterY;
        brand.spacing = 6;
        _brandView = brand;
    }
    return _brandView;
}

- (EZOpenLinkButton *)playButton {
    if (!_playButton) {
        mm_weakify(self);
        _playButton = [self toolbarButtonWithSymbol:@"speaker.wave.2" click:^(EZButton *button) {
            mm_strongify(self);
            if (self.playActionBlock) {
                self.playActionBlock();
            }
        }];
    }
    return _playButton;
}

- (EZOpenLinkButton *)copyButton {
    if (!_copyButton) {
        mm_weakify(self);
        _copyButton = [self toolbarButtonWithSymbol:@"doc.on.doc" click:^(EZButton *button) {
            mm_strongify(self);
            if (self.copyActionBlock) {
                self.copyActionBlock();
            }
        }];
    }
    return _copyButton;
}

- (EZOpenLinkButton *)settingsButton {
    if (!_settingsButton) {
        mm_weakify(self);
        _settingsButton = [self toolbarButtonWithSymbol:@"gearshape" click:^(EZButton *button) {
            mm_strongify(self);
            [self goToSettings];
        }];
    }
    return _settingsButton;
}

- (EZOpenLinkButton *)toolbarButtonWithSymbol:(NSString *)symbol click:(void (^)(EZButton *button))click {
    EZOpenLinkButton *button = [[EZOpenLinkButton alloc] init];
    NSImage *image = [NSImage ez_imageWithSymbolName:symbol];
    button.clickBlock = click;
    NSColor *lightTintColor = [NSColor mm_colorWithHexString:@"#797A7F"];
    NSColor *darkTintColor = [NSColor mm_colorWithHexString:@"#C0C1C4"];
    CGSize imageSize = CGSizeMake(16, 16);
    [button executeOnAppearanceChange:^(EZButton *appearanceButton, BOOL isDarkMode) {
        NSColor *tintColor = isDarkMode ? darkTintColor : lightTintColor;
        appearanceButton.image = [[image imageWithTintColor:tintColor] resizeToSize:imageSize];
    }];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(self.buttonSize);
    }];
    return button;
}

- (NSStackView *)stackView {
    if (!_stackView) {
        _stackView = [[NSStackView alloc] init];
        _stackView.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        _stackView.spacing = self.buttonPadding;
        _stackView.alignment = NSLayoutAttributeCenterY;
        _stackView.userInterfaceLayoutDirection = NSUserInterfaceLayoutDirectionRightToLeft;
        _stackView.detachesHiddenViews = YES;
    }
    return _stackView;
}

- (NSMenu *)quickActionMenu {
    if (!_quickActionMenu) {
        NSMenu *menu = [NSMenu new];
        NSArray *menuSections = @[
            @[
                @{
                    @"title" : @"add_to_favorites",
                    @"action" : NSStringFromSelector(@selector(addFavoriteIfNeeded))
                },
                @{
                    @"title" : @"replace_newline_with_space",
                    @"action" : NSStringFromSelector(@selector(replaceNewlineWithSpace))
                },
                @{
                    @"title" : @"remove_code_comment_symbols",
                    @"action" : NSStringFromSelector(@selector(removeCodeCommentSymbols))
                },
                @{
                    @"title" : @"split_words",
                    @"action" : NSStringFromSelector(@selector(splitWords))
                }
            ],
            [self externalLinkMenuItems],
            @[
                @{
                    @"title" : @"open_app_settings",
                    @"action" : NSStringFromSelector(@selector(goToSettings))
                }
            ]
        ];
        
        for (NSArray *section in menuSections) {
            for (NSDictionary *itemDict in section) {
                NSString *titleKey = itemDict[@"title"];
                NSString *title = NSLocalizedString(titleKey, nil);
                SEL action = NSSelectorFromString(itemDict[@"action"]);
                NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
                menuItem.target = self;
                [menu addItem:menuItem];
            }
            // Add separatorItem
            if (section != menuSections.lastObject && section.count > 0) {
                [menu addItem:[NSMenuItem separatorItem]];
            }
        }
        _quickActionMenu = menu;
    }
    return _quickActionMenu;
}

- (EZOpenLinkButton *)quickActionButton {
    if (!_quickActionButton) {
        EZOpenLinkButton *quickActionButton = [[EZOpenLinkButton alloc] init];
        _quickActionButton = quickActionButton;
        NSImage *image = [NSImage ez_imageWithSymbolName:@"switch.2"];
        quickActionButton.image = image;
        quickActionButton.toolTip = NSLocalizedString(@"quick_action", nil);
        
        mm_weakify(self);
        [quickActionButton setClickBlock:^(EZButton *_Nonnull button) {
            mm_strongify(self);
            [self.quickActionMenu popUpBelowView:self.quickActionButton];
        }];
        
        NSColor *lightTintColor = [NSColor mm_colorWithHexString:@"#797A7F"];
        NSColor *darkTintColor = [NSColor mm_colorWithHexString:@"#C0C1C4"];
        CGSize imageSize = CGSizeMake(20, 20);
        
        [quickActionButton executeOnAppearanceChange:^(EZButton *button, BOOL isDarkMode) {
            NSColor *tintColor = isDarkMode ? darkTintColor : lightTintColor;
            button.image = [[image imageWithTintColor:tintColor] resizeToSize:imageSize];
        }];
        
        [quickActionButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.size.mas_equalTo(24);
        }];
    }
    return _quickActionButton;
}

- (EZOpenLinkButton *)googleButton {
    if (!_googleButton) {
        _googleButton = [self createButtonWithLink:EZGoogleWebSearchURL 
                                         imageName:@"google_icon"
                                        buttonType:EZTitlebarButtonTypeGoogle];
    }
    return _googleButton;
}

- (EZOpenLinkButton *)appleDictionaryButton {
    if (!_appleDictionaryButton) {
        _appleDictionaryButton = [self createButtonWithLink:EZAppleDictionaryAppURLScheme 
                                                  imageName:EZServiceTypeAppleDictionary
                                                 buttonType:EZTitlebarButtonTypeAppleDic];
    }
    return _appleDictionaryButton;
}

- (EZOpenLinkButton *)eudicButton {
    if (!_eudicButton) {
        _eudicButton = [self createButtonWithLink:EZEudicAppURLScheme 
                                        imageName:@"Eudic"
                                       buttonType:EZTitlebarButtonTypeEudicDic];
    }
    return _eudicButton;
}


- (BOOL)pin {
    EZBaseQueryWindow *window = (EZBaseQueryWindow *)self.window;
    return window.pin;
}

- (void)setPin:(BOOL)pin {
    [(EZBaseQueryWindow *)self.window updateWindowLevel:pin];

    [self updatePinButton];
}

- (NSArray<NSNumber *> *)shortcutButtonTypes {
    NSMutableArray *shortcutButtonTypes = [NSMutableArray array];
    
    // Google
    if (MyConfiguration.shared.showGoogleQuickLink) {
        [shortcutButtonTypes addObject:@(EZTitlebarButtonTypeGoogle)];
    }
    
    // Apple Dictionary
    if (MyConfiguration.shared.showAppleDictionaryQuickLink) {
        [shortcutButtonTypes addObject:@(EZTitlebarButtonTypeAppleDic)];
    }
    
    // Eudic
    if (MyConfiguration.shared.showEudicQuickLink) {
        // Fix https://github.com/tisfeng/Easydict/issues/957#issuecomment-3261505123
        // Since edudic has multiple bundle ids, we don't check if installed.
        [shortcutButtonTypes addObject:@(EZTitlebarButtonTypeEudicDic)];
    }
    
    return shortcutButtonTypes.copy;
}

#pragma mark -

- (EZOpenLinkButton *)createButtonWithLink:(NSString *)link
                                 imageName:(NSString *)imageName
                                buttonType:(EZTitlebarButtonType)buttonType
{
    EZOpenLinkButton *button = [[EZOpenLinkButton alloc] init];
    button.link = link;
    button.image = [[NSImage imageNamed:imageName] resizeToSize:self.imageSize];
    button.toolTip = [self toolTipStrWithButtonType:buttonType];
    button.contentTintColor = NSColor.clearColor;
    
    [button mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(self.buttonSize);
    }];
    
    return button;
}

- (EZOpenLinkButton *)buttonWithType:(EZTitlebarButtonType)buttonType {
    EZOpenLinkButton *button;
    switch (buttonType) {
        case EZTitlebarButtonTypeGoogle: {
            button = self.googleButton;
            break;
        }
        case EZTitlebarButtonTypeAppleDic: {
            button = self.appleDictionaryButton;
            break;
        }
        case EZTitlebarButtonTypeEudicDic: {
            button = self.eudicButton;
            break;
        }
        default:
            break;
    }
    
    return button;
}


- (NSString *)toolTipStrWithButtonType:(EZTitlebarButtonType)type {
    NSString *toolTipStr = @"";
    NSString *shortcutStr = @"";
    NSString *hint = @"";
    if (type == EZTitlebarButtonTypePin) {
        shortcutStr = MyConfiguration.shared.pinShortcutString;
        hint = self.pin ? NSLocalizedString(@"unpin", nil) : NSLocalizedString(@"pin", nil);
    } else if (type == EZTitlebarButtonTypeGoogle) {
        shortcutStr = MyConfiguration.shared.googleShortcutString;
        hint = NSLocalizedString(@"open_in_google", nil);
    } else if (type == EZTitlebarButtonTypeAppleDic) {
        shortcutStr = MyConfiguration.shared.appleDictShortcutString;
        hint = NSLocalizedString(@"open_in_apple_dictionary", nil);
    } else if (type == EZTitlebarButtonTypeEudicDic) {
        shortcutStr = MyConfiguration.shared.eudicDictShortcutString;
        hint = NSLocalizedString(@"open_in_eudic", nil);
    }
    if (shortcutStr.length != 0) {
        toolTipStr = [NSString stringWithFormat:@"%@, %@", hint, shortcutStr];
    } else {
        toolTipStr = [NSString stringWithFormat:@"%@", hint];
    }
    return toolTipStr;
}

- (void)updatePinButton {
    self.pinButton.toolTip = [self toolTipStrWithButtonType:EZTitlebarButtonTypePin];
    [self updatePinButtonImage];
}

- (void)updatePinButtonImage {
    CGFloat imageWidth = 18;
    CGSize imageSize = CGSizeMake(imageWidth, imageWidth);

    // Since the system's dark picture mode cannot dynamically follow the mode switch changes, we manually implement dark mode picture coloring.
    NSColor *pinNormalLightTintColor = [NSColor mm_colorWithHexString:@"#797A7F"];
    NSColor *pinNormalDarkTintColor = [NSColor mm_colorWithHexString:@"#C0C1C4"];

    NSImage *normalImage = [[NSImage imageNamed:@"new_pin_normal"] resizeToSize:imageSize];
    NSImage *selectedImage = [[NSImage imageNamed:@"new_pin_selected"] resizeToSize:imageSize];

    BOOL isDarkMode = self.pinButton.isDarkMode;
    NSColor *pinTintColor = isDarkMode ? pinNormalDarkTintColor : pinNormalLightTintColor;
    NSImage *normalTintedImage = [normalImage imageWithTintColor:pinTintColor];
    self.pinButton.image = self.pin ? selectedImage : normalTintedImage;
}

- (void)addFavoriteIfNeeded {
    EZBaseQueryWindow *window = (EZBaseQueryWindow *)self.window;
    EZBaseQueryViewController *viewController = window.queryViewController;
    EZQueryModel *queryModel = viewController.queryModel;
    
    NSString *queryText = queryModel.queryText;
    if (queryText.length == 0) {
        return;
    }
    
    BOOL isFavorited = [QueryRecordManager.shared containsRecordWithQueryText:queryText
                                                                            in:RecordTypeFavorites];
    if (!isFavorited) {
        NSString *translatedResult = [viewController firstTranslatedText];
        [QueryRecordManager.shared addRecordWithQueryText:queryText
                                             fromLanguage:queryModel.queryFromLanguage
                                               toLanguage:queryModel.queryTargetLanguage
                                         translatedResult:translatedResult
                                                      to:RecordTypeFavorites];
    }
}


/// Check if installed app according to bundle id array
- (BOOL)checkInstalledApp:(NSArray<NSString *> *)bundleIds {
    for (NSString *bundleId in bundleIds) {
        if ([[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:bundleId]) {
            return YES;
        }
    }
    return NO;
}

@end
