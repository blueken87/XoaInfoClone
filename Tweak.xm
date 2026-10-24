#import <Foundation/Foundation.h>
#import <substrate.h>

static NSString *XIPReplacement(NSString *item) {
    if ([item hasPrefix:@"expDate:"]) return @"expDate:2099-12-31 23:59:59";
    if ([item hasPrefix:@"phase:"]) return @"phase:9";
    if ([item hasPrefix:@"retention:"]) return @"retention:99999";
    if ([item hasPrefix:@"deleteList:"]) return @"deleteList:";
    if ([item hasPrefix:@"message:"]) return @"message:ok";
    if ([item hasPrefix:@"code:"] || [item isEqualToString:@"code"]) return @"code:0";
    return nil;
}

%hook NSString
- (NSArray *)componentsSeparatedByString:(NSString *)separator {
    NSArray *original = %orig;
    if (![separator isEqualToString:@"|<>|"] || ![self containsString:@"expDate:"]) {
        return original;
    }

    NSLog(@"[XoaInfoPatch] licence raw=%@", self);

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:original.count + 1];
    BOOL hasCode = NO;
    for (NSString *item in original) {
        if (![item isKindOfClass:[NSString class]]) { [result addObject:item]; continue; }
        NSString *replacement = XIPReplacement(item);
        if (replacement != nil) {
            [result addObject:replacement];
            if ([item hasPrefix:@"code"] || [item isEqualToString:@"code"]) hasCode = YES;
        } else {
            [result addObject:item];
        }
    }
    if (!hasCode) [result addObject:@"code:0"];

    NSLog(@"[XoaInfoPatch] licence patched=%@", [result componentsJoinedByString:@"|<>|"]);
    return result;
}
%end

%ctor {
    NSLog(@"[XoaInfoPatch] loaded");
}
