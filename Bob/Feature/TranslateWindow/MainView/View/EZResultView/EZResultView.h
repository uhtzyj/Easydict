//
//  EZResultView.h
//  Bob
//
//  Created by tisfeng on 2022/11/9.
//  Copyright © 2022 ripperhe. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "EZCommonView.h"
#import "WordResultView.h"
#import "TranslateResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface EZResultView : EZCommonView

@property (nonatomic, strong) TranslateResult *result;


//@property (nonatomic, copy) void (^playAudioBlock)(EZCommonView *view, NSString *url);
//@property (nonatomic, copy) void (^copyTextBlock)(EZCommonView *view, NSString *word);

- (void)refreshWithResult:(TranslateResult *)result;
- (void)refreshWithStateString:(NSString *)string;
- (void)refreshWithStateString:(NSString *)string actionTitle:(NSString *_Nullable)actionTitle action:(void (^_Nullable)(void))action;

@end

NS_ASSUME_NONNULL_END
