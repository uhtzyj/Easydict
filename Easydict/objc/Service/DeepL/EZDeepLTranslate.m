//
//  EZDeepLTranslate.m
//  Easydict
//
//  Created by tisfeng on 2022/12/7.
//  Copyright © 2022 izual. All rights reserved.
//

#import "EZDeepLTranslate.h"
#import "Easydict-Swift.h"
#import "EZQueryResult+EZDeepLTranslateResponse.h"

static NSString *kDeepLTranslateURL = @"https://www.deepl.com/translator";

@interface EZDeepLTranslate ()

@property (nonatomic, copy) NSString *authKey;
@property (nonatomic, copy) NSString *deepLTranslateEndPointKey;
@property (nonatomic, assign) EZDeepLTranslationAPI apiType;

@end

@implementation EZDeepLTranslate

- (NSString *)authKey {
    // easydict://writeKeyValue?EZDeepLAuthKey=xxx
    NSString *authKey = [[NSUserDefaults standardUserDefaults] stringForKey:EZDeepLAuthKey] ?: @"";
    return authKey;
}

- (EZDeepLTranslationAPI)apiType {
    // easydict://writeKeyValue?EZDeepLTranslationAPIKey=xxx
    EZDeepLTranslationAPI type = [[NSUserDefaults mm_readString:EZDeepLTranslationAPIKey defaultValue:@"0"] integerValue];
    return type;
}

- (NSString *)deepLTranslateEndPointKey {
    // easydict://writeKeyValue?EZDeepLTranslateEndPointKey=xxx
    NSString *endPointURL = [[NSUserDefaults standardUserDefaults] stringForKey:EZDeepLTranslateEndPointKey] ?: @"";
    return endPointURL;
}

#pragma mark - 重写父类方法

- (EZServiceType)serviceType {
    return EZServiceTypeDeepL;
}

- (NSString *)name {
    return NSLocalizedString(@"deepL_translate", nil);
}

- (NSString *)link {
    return kDeepLTranslateURL;
}

// https://www.deepl.com/translator#en/zh/good
- (nullable NSString *)wordLink:(EZQueryModel *)queryModel {
    NSString *from = [self languageCodeForLanguage:queryModel.queryFromLanguage];
    from = [self removeLanguageVariant:from];

    NSString *to = [self languageCodeForLanguage:queryModel.queryTargetLanguage];
    NSString *text = [queryModel.queryText stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];

    /**
     !!!: need to convert '/' to '%5C%2F'

     e.g. https://www.deepl.com/translator#en/zh/computer%5C%2Fserver

     FIX: https://github.com/tisfeng/Easydict/issues/60
     */
    NSString *encodedText = [text stringByReplacingOccurrencesOfString:@"/" withString:@"%5C%2F"];

    if (!from || !to) {
        return nil;
    }

    NSString *url = [NSString stringWithFormat:@"%@#%@/%@/%@", kDeepLTranslateURL, from, to, encodedText];

    return url;
}

// Supported languages: https://www.deepl.com/zh/docs-api/translate-text/
- (MMOrderedDictionary<EZLanguage, NSString *> *)supportLanguagesDictionary {
    MMOrderedDictionary *orderedDict = [[MMOrderedDictionary alloc] initWithKeysAndObjects:
                                        EZLanguageAuto, @"auto",
                                        EZLanguageSimplifiedChinese, @"zh-hans",
                                        EZLanguageTraditionalChinese, @"zh-hant",
                                        EZLanguageEnglish, @"en",
                                        EZLanguageJapanese, @"ja",
                                        EZLanguageKorean, @"ko",
                                        EZLanguageFrench, @"fr",
                                        EZLanguageSpanish, @"es",
                                        EZLanguagePortuguese, @"pt-PT",
                                        EZLanguageBrazilianPortuguese, @"pt-BR",
                                        EZLanguageItalian, @"it",
                                        EZLanguageGerman, @"de",
                                        EZLanguageRussian, @"ru",
                                        EZLanguageSwedish, @"sv",
                                        EZLanguageRomanian, @"ro",
                                        EZLanguageSlovak, @"sk",
                                        EZLanguageDutch, @"nl",
                                        EZLanguageHungarian, @"hu",
                                        EZLanguageGreek, @"el",
                                        EZLanguageDanish, @"da",
                                        EZLanguageFinnish, @"fi",
                                        EZLanguagePolish, @"pl",
                                        EZLanguageCzech, @"cs",
                                        EZLanguageTurkish, @"tr",
                                        EZLanguageLithuanian, @"lt",
                                        EZLanguageLatvian, @"lv",
                                        EZLanguageUkrainian, @"uk",
                                        EZLanguageBulgarian, @"bg",
                                        EZLanguageIndonesian, @"id",
                                        EZLanguageSlovenian, @"sl",
                                        EZLanguageEstonian, @"et",
                                        EZLanguageNorwegian, @"nb",
                                        EZLanguageArabic, @"ar",
                                        nil];
    return orderedDict;
}

- (void)translate:(NSString *)text from:(EZLanguage)from to:(EZLanguage)to completion:(void (^)(EZQueryResult *, NSError *_Nullable))completion {
    if (self.apiType == EZDeepLTranslationAPIWebFirst) {
        [self deepLWebTranslate:text from:from to:to completion:completion];
    } else {
        [self deepLTranslate:text from:from to:to completion:completion];
    }
}

- (void)ocr:(EZQueryModel *)queryModel completion:(void (^)(EZOCRResult *_Nullable, NSError *_Nullable))completion {
    MMLogError(@"deepL not support ocr");
}

- (BOOL)autoConvertTraditionalChinese {
    return YES;
}

#pragma mark - DeepL Web Translate

/// DeepL web translate. Ref: https://github.com/akl7777777/bob-plugin-akl-deepl-free-translate/blob/9d194783b3eb8b3a82f21bcfbbaf29d6b28c2761/src/main.js
- (void)deepLWebTranslate:(NSString *)text from:(EZLanguage)from to:(EZLanguage)to completion:(void (^)(EZQueryResult *, NSError *_Nullable))completion {
    NSString *sourceLangCode = [self languageCodeForLanguage:from];
    sourceLangCode = [self removeLanguageVariant:sourceLangCode];

    NSString *regionalVariant = [self languageCodeForLanguage:to];
    NSString *targetLangCode = [regionalVariant componentsSeparatedByString:@"-"].firstObject; // pt-PT, pt-BR

    NSString *url = @"https://"
                    @"www2."
                    @"deepl.com"
                    @"/jsonrpc";

    NSInteger ID = [self getRandomNumber];
    NSInteger iCount = [self getICount:text];
    NSTimeInterval ts = [self getTimeStampWithIcount:iCount];

    NSMutableDictionary *params = @{
        @"texts" : @[ @{@"text" : text, @"requestAlternatives" : @(3)} ],
        @"splitting" : @"newlines",
        @"lang" : @{@"source_lang_user_selected" : sourceLangCode, @"target_lang" : targetLangCode},
        @"timestamp" : @(ts),
    }
                                      .mutableCopy;

    if (![regionalVariant isEqualToString:targetLangCode]) {
        NSDictionary *commonJobParams = @{
            @"regionalVariant" : regionalVariant,
            @"mode" : @"translate",
            @"browserType" : @(1),
            @"textType" : @"plaintext",
        };
        params[@"commonJobParams"] = commonJobParams;
    }

    NSDictionary *postData = @{
        @"jsonrpc" : @"2.0",
        @"method" : @"LMT_handle_texts",
        @"id" : @(ID),
        @"params" : params
    };
    //    MMLogInfo(@"postData: %@", postData);

    NSString *postStr = [postData mj_JSONString];
    if ((ID + 5) % 29 == 0 || (ID + 3) % 13 == 0) {
        postStr = [postStr stringByReplacingOccurrencesOfString:@"\"method\":\"" withString:@"\"method\" : \""];
    } else {
        postStr = [postStr stringByReplacingOccurrencesOfString:@"\"method\":\"" withString:@"\"method\": \""];
    }
    NSData *postDataData = [postStr dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = postDataData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    AFURLSessionManager *manager = [[AFURLSessionManager alloc] init];
    manager.session.configuration.timeoutIntervalForRequest = EZNetWorkTimeoutInterval;

    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();

    NSURLSessionTask *task = [manager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse *_Nonnull response, id _Nullable responseObject, NSError *_Nullable error) {
        if ([self.queryModel isServiceStopped:self.serviceType]) {
            return;
        }

        if (error.code == NSURLErrorCancelled) {
            return;
        }

        if (error) {
            MMLogError(@"deepLWebTranslate error: %@", error);
            EZQueryError *queryError = [EZQueryError errorWithType:EZQueryErrorTypeApi message:error.localizedDescription];

            BOOL useOfficialAPI = (self.authKey.length > 0) && (self.apiType == EZDeepLTranslationAPIWebFirst);
            if (useOfficialAPI) {
                [self deepLTranslate:text from:from to:to completion:completion];
                return;
            }

            NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
            if (errorData) {
                /**
                 {
                   "error" : {
                     "code" : 1042912,
                     "message" : "Too many requests"
                   },
                   "jsonrpc" : "2.0"
                 }
                 */
                NSError *jsonError;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:errorData options:kNilOptions error:&jsonError];
                if (!jsonError) {
                    NSString *errorMessage = json[@"error"][@"message"];
                    if (errorMessage.length) {
                        queryError.errorDataMessage = errorMessage;
                    }
                }
            }

            completion(self.result, queryError);
            return;
        }

        CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
        MMLogInfo(@"deepLWebTranslate cost: %.1f ms", (endTime - startTime) * 1000);

        EZDeepLTranslateResponse *deepLTranslateResponse = [EZDeepLTranslateResponse mj_objectWithKeyValues:responseObject];
        NSString *translatedText = [deepLTranslateResponse.result.texts.firstObject.text trim];
        if (translatedText) {
            NSArray *results = [translatedText toParagraphs];
            self.result.translatedResults = results;
            self.result.raw = deepLTranslateResponse;
        }
        completion(self.result, nil);
    }];
    [task resume];

    [self.queryModel setStopBlock:^{
        [task cancel];
    } serviceType:self.serviceType];
}


- (NSInteger)getICount:(NSString *)translateText {
    return [[translateText componentsSeparatedByString:@"i"] count] - 1;
}

- (NSInteger)getRandomNumber {
    NSInteger rand = arc4random_uniform(89999) + 100000;
    return rand * 1000;
}

- (NSInteger)getTimeStampWithIcount:(NSInteger)iCount {
    NSInteger ts = [[NSDate date] timeIntervalSince1970] * 1000;
    if (iCount != 0) {
        iCount = iCount + 1;
        return ts - (ts % iCount) + iCount;
    } else {
        return ts;
    }
}

#pragma mark - DeepL Official Translate API

- (void)deepLTranslate:(NSString *)text from:(EZLanguage)from to:(EZLanguage)to completion:(void (^)(EZQueryResult *, NSError *_Nullable))completion {
    // Docs: https://www.deepl.com/zh/docs-api/translating-text

    NSString *souceLangCode = [self languageCodeForLanguage:from];
    souceLangCode = [self removeLanguageVariant:souceLangCode];

    NSString *targetLangCode = [self languageCodeForLanguage:to];

    // DeepL api free and deepL pro api use different url host.
    BOOL isFreeKey = [self.authKey hasSuffix:@":fx"];
    NSString *host = isFreeKey ? @"https://api-free.deepl.com" : @"https://api.deepl.com";
    NSString *url = [NSString stringWithFormat:@"%@/v2/translate", host];

    if (self.deepLTranslateEndPointKey.length) {
        url = self.deepLTranslateEndPointKey;
    }

    NSDictionary *params = @{
        @"text" : text,
        @"source_lang" : souceLangCode,
        @"target_lang" : targetLangCode
    };

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.session.configuration.timeoutIntervalForRequest = EZNetWorkTimeoutInterval;

    NSString *authorization = [NSString stringWithFormat:@"DeepL-Auth-Key %@", self.authKey];
    [manager.requestSerializer setValue:authorization forHTTPHeaderField:@"Authorization"];

    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();

    NSURLSessionTask *task = [manager POST:url parameters:params progress:nil success:^(NSURLSessionDataTask *_Nonnull task, id _Nullable responseObject) {
        CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
        MMLogInfo(@"deepLTranslate cost: %.1f ms", (endTime - startTime) * 1000);

        self.result.translatedResults = [self parseOfficialResponseObject:responseObject];
        self.result.raw = responseObject;
        completion(self.result, nil);
    } failure:^(NSURLSessionDataTask *_Nullable task, NSError *_Nonnull error) {
        if ([self.queryModel isServiceStopped:self.serviceType]) {
            return;
        }

        if (error.code == NSURLErrorCancelled) {
            return;
        }

        MMLogError(@"deepLTranslate error: %@", error);

        if (self.apiType == EZDeepLTranslationAPIOfficialFirst) {
            [self deepLWebTranslate:text from:from to:to completion:completion];
            return;
        }

        EZQueryError *queryError = [EZQueryError errorWithType:EZQueryErrorTypeApi message:error.localizedDescription];

        completion(self.result, queryError);
    }];

    [self.queryModel setStopBlock:^{
        [task cancel];
    } serviceType:self.serviceType];
}


- (NSArray<NSString *> *)parseOfficialResponseObject:(NSDictionary *)responseObject {
    /**
     {
       "translations" : [
         {
           "detected_source_language" : "EN",
           "text" : "很好"
         }
       ]
     }
     */
    NSString *translatedText = [responseObject[@"translations"] firstObject][@"text"];
    NSArray *translatedTextArray = [translatedText toParagraphs];

    return translatedTextArray;
}

#pragma mark -

/// Remove language variant, e.g. zh-hans --> zh, pt-BR --> pt
/// Since DeepL API source language code is different from the target language code, it has no variant.
/// DeepL Docs: https://developers.deepl.com/docs/zh/resources/supported-languages#source-languages
- (NSString *)removeLanguageVariant:(NSString *)languageCode {
    return [languageCode componentsSeparatedByString:@"-"].firstObject;
}

@end
