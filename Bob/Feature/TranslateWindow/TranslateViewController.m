//
//  ViewController.m
//  Bob
//
//  Created by ripper on 2019/10/19.
//  Copyright © 2019 ripperhe. All rights reserved.
//

#import "TranslateViewController.h"
#import "BaiduTranslate.h"
#import "YoudaoTranslate.h"
#import "GoogleTranslate.h"
#import "Selection.h"
#import "PopUpButton.h"
#import "QueryView.h"
#import "ResultView.h"
#import "Configuration.h"
#import <AVFoundation/AVFoundation.h>
#import "ImageButton.h"
#import "TranslateWindowController.h"
#import "FlippedView.h"

#define kMargin 12.0
#define kQueryMinHeight 90.0
#define kResultMinHeight 120.0

#define increaseSeed               \
NSUInteger seed = ++self.seed; \
if (seed == NSUIntegerMax) {   \
seed = 0;                  \
self.seed = 0;             \
}
#define checkSeed                                   \
if (seed != self.seed) {                        \
MMLogInfo(@"过滤失效的网络回调 %zd", seed); \
return;                                     \
}


@interface TranslateViewController ()

@property (nonatomic, strong) NSArray<Translate *> *translateArray;
@property (nonatomic, strong) Translate *translate;
@property (nonatomic, assign) BOOL isTranslating;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) TranslateResult *currentResult;
@property (nonatomic, strong) MMEventMonitor *monitor;
@property (nonatomic, assign) NSUInteger seed;

@property (nonatomic, strong) NSButton *pinButton;
@property (nonatomic, strong) NSButton *foldButton;
@property (nonatomic, strong) NSButton *linkButton;
@property (nonatomic, strong) QueryView *queryView;
@property (nonatomic, strong) PopUpButton *translateButton;
@property (nonatomic, strong) PopUpButton *fromLanguageButton;
@property (nonatomic, strong) ImageButton *transformButton;
@property (nonatomic, strong) PopUpButton *toLanguageButton;
@property (nonatomic, strong) ResultView *resultView;
@property (strong, nonatomic) NSScrollView *scrollView;
@property (nonatomic, strong) NSMutableArray<ResultView *> *resultViewArray;

@property (nonatomic, assign) CGFloat queryHeightWhenFold;
@property (nonatomic, strong) MASConstraint *queryHeightConstraint;
//@property (nonatomic, strong) MASConstraint *resultTopConstraint;

@end


@implementation TranslateViewController

- (BOOL)acceptsFirstResponder {
    return YES;
}

/// 用代码创建 NSViewController 貌似不会自动创建 view，需要手动初始化
- (void)loadView {
    self.view = [NSView new];
    self.view.wantsLayer = YES;
    self.view.layer.cornerRadius = 4;
    self.view.layer.masksToBounds = YES;
    [self.view excuteLight:^(NSView *_Nonnull x) {
        x.layer.backgroundColor = NSColor.whiteColor.CGColor;
        x.layer.borderWidth = 0;
    } drak:^(NSView *_Nonnull x) {
        x.layer.backgroundColor = DarkBorderColor.CGColor;
        x.layer.borderColor = [[NSColor whiteColor] colorWithAlphaComponent:0.15].CGColor;
        x.layer.borderWidth = 1;
    }];
    self.resultViewArray = [NSMutableArray array];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupMonitor];
    [self setupTranslate];
    [self setupViews];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    if (!Configuration.shared.isPin) {
        [self.monitor start];
    }
    if (!Configuration.shared.isFold) {
        [self makeTextViewBecomeFirstResponser];
    }
}

- (void)viewDidDisappear {
    [super viewDidDisappear];
    
    [self.monitor stop];
    [self.player pause];
}

#pragma mark -

- (void)setupViews {
    self.view.wantsLayer = YES;
    self.view.layer.cornerRadius = 10;
    self.pinButton = [NSButton mm_make:^(NSButton *button) {
        [self.view addSubview:button];
        button.bordered = NO;
        button.imageScaling = NSImageScaleProportionallyDown;
        button.bezelStyle = NSBezelStyleRegularSquare;
        [button setButtonType:NSButtonTypeToggle];
        button.image = [NSImage imageNamed:@"pin_normal"];
        button.alternateImage = [NSImage imageNamed:@"pin_selected"];
        button.mm_isOn = Configuration.shared.isPin;
        button.toolTip = button.mm_isOn ? @"取消钉住" : @"钉住";
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.offset(6);
            make.width.height.mas_equalTo(32);
        }];
        mm_weakify(button)
        [button setRac_command:[[RACCommand alloc] initWithSignalBlock:^RACSignal *_Nonnull(id _Nullable input) {
            mm_strongify(button)
            Configuration.shared.isPin = button.mm_isOn;
            if (button.mm_isOn) {
                [self.monitor stop];
            } else {
                [self.monitor start];
            }
            button.toolTip = button.mm_isOn ? @"取消钉住" : @"钉住";
            return RACSignal.empty;
        }]];
    }];
    
    self.foldButton = [NSButton mm_make:^(NSButton *_Nonnull button) {
        [self.view addSubview:button];
        button.bordered = NO;
        button.imageScaling = NSImageScaleProportionallyDown;
        button.bezelStyle = NSBezelStyleRegularSquare;
        [button setButtonType:NSButtonTypeToggle];
        button.image = [NSImage imageNamed:@"fold_up"];
        button.alternateImage = [NSImage imageNamed:@"fold_down"];
        button.mm_isOn = Configuration.shared.isFold;
        button.toolTip = button.mm_isOn ? @"展开" : @"折叠";
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.offset(9);
            make.right.inset(9);
            make.width.height.mas_equalTo(26);
        }];
        mm_weakify(button)
        [button setRac_command:[[RACCommand alloc] initWithSignalBlock:^RACSignal *_Nonnull(id _Nullable input) {
            mm_strongify(button)
            Configuration.shared.isFold = button.mm_isOn;
            [self updateFoldState:button.mm_isOn];
            button.toolTip = button.mm_isOn ? @"展开" : @"折叠";
            return RACSignal.empty;
        }]];
    }];
    
    self.linkButton = [NSButton mm_make:^(NSButton *_Nonnull button) {
        [self.view addSubview:button];
        button.bordered = NO;
        button.imageScaling = NSImageScaleProportionallyDown;
        button.bezelStyle = NSBezelStyleRegularSquare;
        [button setButtonType:NSButtonTypeToggle];
        button.image = [NSImage imageNamed:@"link"];
        button.toolTip = @"跳转网页";
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.foldButton);
            make.right.equalTo(self.foldButton.mas_left).inset(8);
            make.width.height.equalTo(self.foldButton);
        }];
        mm_weakify(self)
        [button setRac_command:[[RACCommand alloc] initWithSignalBlock:^RACSignal *_Nonnull(id _Nullable input) {
            mm_strongify(self)
            NSString *link = self.translate.link;
            if (self.currentResult.link && [ self.queryView.queryText isEqualToString:self.currentResult.text]) {
                link = self.currentResult.link;
            }
            NSLog(@"%@", link);
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:link]];
            if (!Configuration.shared.isPin) {
                [TranslateWindowController.shared close];
            }
            return RACSignal.empty;
        }]];
    }];
    
    self.queryView = [QueryView mm_make:^(QueryView *_Nonnull view) {
        [self.view addSubview:view];
        [view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.pinButton.mas_bottom).offset(2);
            make.left.right.inset(kMargin);
//            self.queryHeightConstraint = make.height.greaterThanOrEqualTo(@(kQueryMinHeight));
            self.queryHeightConstraint = make.height.equalTo(@(kQueryMinHeight));

        }];
        [view setCopyActionBlock:^(QueryView *_Nonnull view) {
            [NSPasteboard mm_generalPasteboardSetString:view.queryText];
        }];
        mm_weakify(self)
        [view setAudioActionBlock:^(QueryView *_Nonnull view) {
            mm_strongify(self);
            if ([self.currentResult.text isEqualToString:view.queryText]) {
                if (self.currentResult.fromSpeakURL) {
                    [self playAudioWithURL:self.currentResult.fromSpeakURL];
                } else {
                    [self playAudioWithText:self.currentResult.text lang:self.currentResult.from];
                }
            } else {
                [self playAudioWithText:view.queryText lang:Configuration.shared.from];
            }
        }];
        [view setEnterActionBlock:^(QueryView *_Nonnull view) {
            mm_strongify(self);
            if (view.queryText.length) {
                [self translateText:view.queryText];
            }
        }];
    }];
    
    self.translateButton = [PopUpButton mm_make:^(PopUpButton *_Nonnull button) {
        [self.view addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.queryView.mas_bottom).offset(12);
            make.left.offset(kMargin);
            make.width.mas_greaterThanOrEqualTo(100);
            make.width.mas_lessThanOrEqualTo(200);
            make.height.mas_equalTo(25);
        }];
        [button updateMenuWithTitleArray:[self.translateArray mm_map:^id _Nullable(Translate *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            return obj.name;
        }]];
        [button updateWithIndex:[[self.translateArray mm_find:^id _Nullable(Translate *_Nonnull obj, NSUInteger idx) {
            return obj == self.translate ? @(idx) : nil;
        }] integerValue]];
        mm_weakify(self);
        [button setMenuItemSeletedBlock:^(NSInteger index, NSString *title) {
            mm_strongify(self);
            Translate *t = [self.translateArray objectAtIndex:index];
            if (t != self.translate) {
                Configuration.shared.translateIdentifier = t.identifier;
                self.translate = t;
                [self refreshForSwitchTranslate];
            }
        }];
    }];
    
    self.fromLanguageButton = [PopUpButton mm_make:^(PopUpButton *_Nonnull button) {
        [self.view addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.translateButton.mas_bottom).offset(12);
            make.left.offset(kMargin);
            make.width.mas_equalTo(100);
            make.height.mas_equalTo(25);
        }];
        [button updateMenuWithTitleArray:[self.translate.languages mm_map:^id _Nullable(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            if ([obj integerValue] == Language_auto) {
                return @"自动检测";
            }
            return LanguageDescFromEnum([obj integerValue]);
        }]];
        [button updateWithIndex:[self.translate indexForLanguage:Configuration.shared.from]];
        mm_weakify(self);
        [button setMenuItemSeletedBlock:^(NSInteger index, NSString *title) {
            mm_strongify(self);
            NSInteger from = [[self.translate.languages objectAtIndex:index] integerValue];
            NSLog(@"from 选中语言 %zd %@", from, LanguageDescFromEnum(from));
            if (from != Configuration.shared.from) {
                Configuration.shared.from = from;
                [self retry];
            }
        }];
    }];
    
    self.transformButton = [ImageButton mm_make:^(NSButton *_Nonnull button) {
        [self.view addSubview:button];
        button.bordered = NO;
        button.toolTip = @"交换语言";
        button.imageScaling = NSImageScaleProportionallyDown;
        button.bezelStyle = NSBezelStyleRegularSquare;
        [button setButtonType:NSButtonTypeMomentaryChange];
        button.image = [NSImage imageNamed:@"transform"];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.fromLanguageButton);
            make.left.equalTo(self.fromLanguageButton.mas_right).offset(20);
            make.width.equalTo(@40);
            make.height.equalTo(@40);
        }];
        mm_weakify(self)
        [button setRac_command:[[RACCommand alloc] initWithSignalBlock:^RACSignal *_Nonnull(id _Nullable input) {
            mm_strongify(self)
            Language from = Configuration.shared.from;
            Configuration.shared.from = Configuration.shared.to;
            Configuration.shared.to = from;
            [self.fromLanguageButton updateWithIndex:[self.translate indexForLanguage:Configuration.shared.from]];
            [self.toLanguageButton updateWithIndex:[self.translate indexForLanguage:Configuration.shared.to]];
            [self retry];
            return RACSignal.empty;
        }]];
    }];
    
    self.toLanguageButton = [PopUpButton mm_make:^(PopUpButton *_Nonnull button) {
        [self.view addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.transformButton.mas_right).offset(20);
            make.centerY.equalTo(self.transformButton);
            make.width.height.equalTo(self.fromLanguageButton);
            make.right.lessThanOrEqualTo(self.view.mas_right).offset(-kMargin);
        }];
        [button updateMenuWithTitleArray:[self.translate.languages mm_map:^id _Nullable(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            if ([obj integerValue] == Language_auto) {
                return @"自动选择";
            }
            return LanguageDescFromEnum([obj integerValue]);
        }]];
        [button updateWithIndex:[self.translate indexForLanguage:Configuration.shared.to]];
        mm_weakify(self);
        [button setMenuItemSeletedBlock:^(NSInteger index, NSString *title) {
            mm_strongify(self);
            NSInteger to = [[self.translate.languages objectAtIndex:index] integerValue];
            NSLog(@"to 选中语言 %zd %@", to, LanguageDescFromEnum(to));
            if (to != Configuration.shared.to) {
                Configuration.shared.to = to;
                [self retry];
            }
        }];
    }];
    
    NSScrollView *scrollView = NSScrollView.new;
    scrollView.translatesAutoresizingMaskIntoConstraints = YES;
    scrollView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasVerticalRuler = YES;

    scrollView.wantsLayer = YES;
    scrollView.layer.cornerRadius = 10;
    scrollView.layer.masksToBounds = YES;
    self.scrollView = scrollView;
    [self.view addSubview:scrollView];
    [self.scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.fromLanguageButton.mas_bottom).offset(12);
        make.left.right.equalTo(self.queryView);
        make.bottom.inset(kMargin);
    }];
    
    
    FlippedView *contentView = [[FlippedView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = YES;
    contentView.identifier = @"Content container";

    contentView.wantsLayer = YES;
    self.scrollView.documentView = contentView;
//    self.scrollView.contentView = contentView;
    
    
    [contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.scrollView);
        make.width.greaterThanOrEqualTo(self.scrollView);
    }];
    

    __block NSView *lastView;
    for ( Translate *translate in self.translateArray) {
        NSLog(@"translate: %@", translate.name);
        
        [ResultView mm_anyMake:^(ResultView *_Nonnull view) {
            [contentView addSubview:view];
            view.wantsLayer = YES;
//            view.layer.backgroundColor = NSColor.redColor.CGColor;
            
            [view mas_makeConstraints:^(MASConstraintMaker *make) {
//                if (Configuration.shared.isFold) {
//                    self.resultTopConstraint = make.top.equalTo(self.pinButton.mas_bottom).offset(2);
//                } else {
//                    self.resultTopConstraint = make.top.equalTo(self.fromLanguageButton.mas_bottom).offset(12);
//                }
                                
                if (lastView == nil) {
                    make.top.equalTo(self.scrollView).offset(0);
                } else {
                    make.top.equalTo(  lastView.mas_bottom).offset(12);
                }
                
                make.left.right.width.equalTo(self.scrollView);
                make.height.greaterThanOrEqualTo(@(kResultMinHeight));
            }];
            mm_weakify(self)
            [view.normalResultView setAudioActionBlock:^(NormalResultView *_Nonnull view) {
                mm_strongify(self);
                if (!self.currentResult) return;
                if (self.currentResult.toSpeakURL) {
                    [self playAudioWithURL:self.currentResult.toSpeakURL];
                } else {
                    [self playAudioWithText:[NSString mm_stringByCombineComponents:self.currentResult.normalResults separatedString:@"\n"] lang:self.currentResult.to];
                }
            }];
            [view.normalResultView setCopyActionBlock:^(NormalResultView *_Nonnull view) {
                mm_strongify(self);
                if (!self.currentResult) return;
                [NSPasteboard mm_generalPasteboardSetString:view.textView.string];
            }];
            [view.wordResultView setPlayAudioBlock:^(WordResultView *_Nonnull view, NSString *_Nonnull url) {
                mm_strongify(self);
                [self playAudioWithURL:url];
            }];
            [view.wordResultView setSelectWordBlock:^(WordResultView *_Nonnull view, NSString *_Nonnull word) {
                mm_strongify(self);
                [NSPasteboard mm_generalPasteboardSetString:word];
                [self translateText:word];
            }];
            
            [self.resultViewArray addObject:view];
            lastView = view;
        }];
    }
    
    [contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(lastView).offset(0);
    }];
    
    contentView.wantsLayer = YES;
    self.scrollView.documentView = contentView;
//    self.scrollView.contentView = contentView;
    
    [self updateFoldState:Configuration.shared.isFold];
}

- (void)setupTranslate {
    self.translateArray = @[
        [YoudaoTranslate new],
        [BaiduTranslate new],
        [GoogleTranslate new],
    ];
    self.translate = [self.translateArray mm_find:^id(Translate *_Nonnull obj, NSUInteger idx) {
        return [obj.identifier isEqualToString:Configuration.shared.translateIdentifier] ? obj : nil;
    }];
    if (!self.translate) {
        self.translate = self.translateArray.firstObject;
    }
    self.player = [[AVPlayer alloc] init];
}

- (void)setupMonitor {
    mm_weakify(self)
    self.monitor = [MMEventMonitor globalMonitorWithEvent:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown handler:^(NSEvent *_Nonnull event) {
        mm_strongify(self);
        if (NSPointInRect([NSEvent mouseLocation], TranslateWindowController.shared.window.frame)) {
            // TODO: 这个问题偶然出现，原因暂未找到
            MMLogVerbose(@"❌ 鼠标在翻译 window 内部点击依旧触发了全局事件");
            return;
        }
        if (!Configuration.shared.isPin) {
            // 关闭视图
            [TranslateWindowController.shared close];
            [self.monitor stop];
        }
    }];
}

#pragma mark -

- (void)resetWithState:(NSString *)stateString query:(NSString *)query actionTitle:(NSString *)actionTitle action:(void (^)(void))action {
    self.currentResult = nil;
     self.queryView.queryText = query ?: @"";
    [self.resultView refreshWithStateString:stateString actionTitle:actionTitle action:action];
    [self resizeWindowWithQueryViewExpectHeight:0];
}

- (void)resetWithState:(NSString *)stateString query:(NSString *)query {
    [self resetWithState:stateString query:query actionTitle:nil action:nil];
}

- (void)resetWithState:(NSString *)stateString {
    [self resetWithState:stateString query:nil actionTitle:nil action:nil];
}

- (void)resetWithState:(NSString *)stateString actionTitle:(NSString *)actionTitle action:(void (^)(void))action {
    [self resetWithState:stateString query:nil actionTitle:actionTitle action:action];
}

- (void)translateText:(NSString *)text {
    self.isTranslating = YES;
    [self resetWithState:@"翻译中..." query:text];
    increaseSeed
    mm_weakify(self)
    [self.translate translate:text
                         from:Configuration.shared.from
                           to:Configuration.shared.to
                   completion:^(TranslateResult *_Nullable result, NSError *_Nullable error) {
        mm_strongify(self);
        checkSeed
        self.isTranslating = NO;
        [self refreshWithTranslateResult:result error:error];
        
        for (ResultView *resultView in self.resultViewArray) {
            [resultView refreshWithResult:result];
        }
        
        NSString *lang = LanguageDescFromEnum(result.from);
        self.queryView.detectLanguage = lang;
    }];
}

- (void)translateImage:(NSImage *)image {
    self.isTranslating = YES;
    [self resetWithState:@"图片文本识别中..."];
    increaseSeed
    mm_weakify(self)
    [self.translate ocrAndTranslate:image
                               from:Configuration.shared.from
                                 to:Configuration.shared.to
                         ocrSuccess:^(OCRResult *_Nonnull result, BOOL willInvokeTranslateAPI) {
        mm_strongify(self)
        checkSeed
        [NSPasteboard mm_generalPasteboardSetString:result.mergedText];
         self.queryView.queryText = result.mergedText;
        if (!willInvokeTranslateAPI) {
            [self.resultView refreshWithStateString:@"翻译中..."];
        }
    }
                         completion:^(OCRResult *_Nullable ocrResult, TranslateResult *_Nullable result, NSError *_Nullable error) {
        mm_strongify(self)
        checkSeed
        self.isTranslating = NO;
        NSLog(@"识别到的文本:\n%@", ocrResult.mergedText);
        [self refreshWithTranslateResult:result error:error];
    }];
}

- (void)refreshWithTranslateResult:(TranslateResult *)result error:(NSError *)error {
    if (Configuration.shared.autoCopyTranslateResult) {
        // 自动拷贝翻译结果，如果翻译失败，则清空剪切板
        [NSPasteboard mm_generalPasteboardSetString:[NSString mm_stringByCombineComponents:result.normalResults separatedString:@"\n"]];
    }
    if (error) {
        [self.resultView refreshWithStateString:error.localizedDescription];
        NSString *errorInfo = [NSString stringWithFormat:@"%@\n%@", error.localizedDescription, [error.userInfo objectForKey:TranslateErrorRequestKey]];
        MMLogInfo(@"%@", errorInfo);
    } else {
        self.currentResult = result;
        [self.resultView refreshWithResult:result];
    }
    mm_weakify(self)
    dispatch_async(dispatch_get_main_queue(), ^{
        mm_strongify(self);
        [self moveWindowToScreen];
        [self resetQueryViewHeightConstraint];
    });
}

- (void)retry {
    if (self.isTranslating) {
        return;
    }
    if (self.currentResult) {
        [self translateText:self.currentResult.text];
    } else if ( self.queryView.queryText.length) {
        [self translateText: self.queryView.queryText];
    }
}

- (void)refreshForSwitchTranslate {
    [self.fromLanguageButton updateMenuWithTitleArray:[self.translate.languages mm_map:^id _Nullable(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if ([obj integerValue] == Language_auto) {
            return @"自动检测";
        }
        return LanguageDescFromEnum([obj integerValue]);
    }]];
    NSInteger fromIndex = [self.translate indexForLanguage:Configuration.shared.from];
    Configuration.shared.from = [[self.translate.languages objectAtIndex:fromIndex] integerValue];
    [self.fromLanguageButton updateWithIndex:fromIndex];
    
    [self.toLanguageButton updateMenuWithTitleArray:[self.translate.languages mm_map:^id _Nullable(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if ([obj integerValue] == Language_auto) {
            return @"自动选择";
        }
        return LanguageDescFromEnum([obj integerValue]);
    }]];
    NSInteger toIndex = [self.translate indexForLanguage:Configuration.shared.to];
    Configuration.shared.to = [[self.translate.languages objectAtIndex:toIndex] integerValue];
    [self.toLanguageButton updateWithIndex:toIndex];
    
    // 强制重刷
    self.isTranslating = NO;
    [self retry];
}

- (void)playAudioWithText:(NSString *)text lang:(Language)lang {
    if (text.length) {
        mm_weakify(self)
        [self.translate audio:text from:lang completion:^(NSString *_Nullable url, NSError *_Nullable error) {
            mm_strongify(self);
            if (!error) {
                [self playAudioWithURL:url];
            } else {
                MMLogInfo(@"获取音频 URL 失败 %@", error);
            }
        }];
    }
}

- (void)playAudioWithURL:(NSString *)url {
    MMLogInfo(@"播放音频 %@", url);
    [self.player pause];
    if (!url.length) return;
    [self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:[NSURL URLWithString:url]]];
    [self.player play];
}

- (void)makeTextViewBecomeFirstResponser {
    @try {
        [self.window makeFirstResponder:self.queryView.textView];
    } @catch (NSException *exception) {
        MMLogInfo(@"聚焦输入框异常 %@", exception);
    }
}



#pragma mark - window frame

- (void)viewDidLayout {
    [super viewDidLayout];
    
    NSLog(@"viewDidLayout");
}


- (void)resetQueryViewHeightConstraint {
    self.queryHeightConstraint.equalTo(@(kQueryMinHeight));
}

- (void)updateFoldState:(BOOL)isFold {
    self.foldButton.mm_isOn = isFold;
    if (isFold) {
        self.queryHeightWhenFold = self.queryView.frame.size.height;
    }
    self.queryView.hidden = isFold;
    self.translateButton.hidden = isFold;
    self.fromLanguageButton.hidden = isFold;
    self.transformButton.hidden = isFold;
    self.toLanguageButton.hidden = isFold;
//    [self.resultTopConstraint uninstall];
//    [self.resultView mas_updateConstraints:^(MASConstraintMaker *make) {
//        if (isFold) {
//            self.resultTopConstraint = make.top.equalTo(self.pinButton.mas_bottom).offset(2);
//        } else {
//            self.resultTopConstraint = make.top.equalTo(self.fromLanguageButton.mas_bottom).offset(12);
//        }
//    }];
    [self resizeWindowWithQueryViewExpectHeight:self.queryHeightWhenFold];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!isFold) {
            [self makeTextViewBecomeFirstResponser];
        }
        [self resetQueryViewHeightConstraint];
    });
}

// 保证 result size 达到最小
- (void)resizeWindowWithQueryViewExpectHeight:(CGFloat)expectHeight {
    NSPoint topLeft = self.window.topLeft;
    CGFloat height = expectHeight > 0 ? expectHeight : self.queryView.frame.size.height;
    self.queryHeightConstraint.equalTo(@(height > kQueryMinHeight ? height : kQueryMinHeight));
    [self.window setContentSize:CGSizeMake(self.window.frame.size.width, 0)];
    [self.window setTopLeft:topLeft];
    // 等待合适的时机重置查询视图最小高度
}

- (void)moveWindowToScreen {
    NSRect windowFrame = self.window.frame;
    NSRect visibleFrame = self.window.screen.visibleFrame;
    if (windowFrame.origin.y < visibleFrame.origin.y + 10) {
        windowFrame.origin.y = visibleFrame.origin.y + 10;
    }
    if (windowFrame.origin.x > visibleFrame.origin.x + visibleFrame.size.width - windowFrame.size.width - 10) {
        windowFrame.origin.x = visibleFrame.origin.x + visibleFrame.size.width - windowFrame.size.width - 10;
    }
    if (!NSEqualRects(self.window.frame, windowFrame)) {
        [self.window setFrame:windowFrame display:YES animate:YES];
    }
}

@end
