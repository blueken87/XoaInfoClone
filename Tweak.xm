#import <Foundation/Foundation.h>
#import <substrate.h>

static BOOL s_inSplit = NO;

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
    if (s_inSplit) return %orig;
    if (separator == nil || ![separator isEqualToString:@"|<>|"]) return %orig;

    NSArray *original = %orig;
    if (original.count < 2) return original;

    s_inSplit = YES;
    NSArray *result = original;
    @try {
        if ([self rangeOfString:@"expDate:"].location != NSNotFound) {
            NSLog(@"[XoaInfoPatch] raw=%@", self);
            NSMutableArray *patched = [NSMutableArray arrayWithCapacity:original.count + 1];
            BOOL hasCode = NO;
            for (id item in original) {
                if (![item isKindOfClass:[NSString class]]) { [patched addObject:item]; continue; }
                NSString *replacement = XIPReplacement(item);
                if (replacement != nil) {
                    [patched addObject:replacement];
                    if ([item hasPrefix:@"code"]) hasCode = YES;
                } else {
                    [patched addObject:item];
                }
            }
            if (!hasCode) [patched addObject:@"code:0"];
            result = patched;
            NSLog(@"[XoaInfoPatch] patched=%@", [patched componentsJoinedByString:@"|<>|"]);
        }
    } @catch (NSException *exception) {
        NSLog(@"[XoaInfoPatch] exception %@", exception);
        result = original;
    }
    s_inSplit = NO;
    return result;
}
%end

%ctor {
    NSLog(@"[XoaInfoPatch] loaded");
}
