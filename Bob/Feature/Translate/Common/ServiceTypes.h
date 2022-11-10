//
//  TranslateTypeMap.h
//  Bob
//
//  Created by tisfeng on 2022/11/5.
//  Copyright © 2022 ripperhe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TranslateService.h"

NS_ASSUME_NONNULL_BEGIN

@interface ServiceTypes : NSObject

+ (NSArray<EZServiceType> *)allServiceTypes;

+ (NSDictionary<EZServiceType, TranslateService *> *)serviceDict;

+ (TranslateService *)serviceWithType:(EZServiceType)type;

@end

NS_ASSUME_NONNULL_END
