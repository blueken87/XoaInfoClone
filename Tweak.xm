#import <Foundation/Foundation.h>
#import <substrate.h>

static void XIPSetLike(NSMutableDictionary *dict, NSString *key, id numberValue, id stringValue) {
    id current = dict[key];
    if ([current isKindOfClass:[NSNumber class]]) {
        dict[key] = numberValue;
    } else if (current != nil) {
        dict[key] = stringValue;
    }
}

static void XIPForceLicensed(NSMutableDictionary *dict) {
    XIPSetLike(dict, @"code", @0, @"0");
    XIPSetLike(dict, @"success", @YES, @"1");
    XIPSetLike(dict, @"phase", @9, @"9");
    XIPSetLike(dict, @"retention", @99999, @"99999");
    dict[@"message"] = @"ok";
    dict[@"expDate"] = @"2099-12-31 23:59:59";
}

static NSMutableDictionary *XIPParseDelimited(NSData *data) {
    NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (raw == nil) return nil;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *pair in [raw componentsSeparatedByString:@"|<>|"]) {
        NSRange colon = [pair rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *key = [[pair substringToIndex:colon.location]
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *value = [[pair substringFromIndex:colon.location + 1]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (key.length) dict[key] = value;
    }
    return dict.count ? dict : nil;
}

%hook NSJSONSerialization
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)options error:(NSError **)error {
    id object = %orig;
    @try {
        NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        BOOL isLicence = NO;
        if (raw != nil && ([raw rangeOfString:@"loginipX2.1"].location != NSNotFound ||
                           [raw rangeOfString:@"redeemcode"].location != NSNotFound ||
                           [raw rangeOfString:@"expDate"].location != NSNotFound)) {
            isLicence = YES;
        }
        if (!isLicence && [object isKindOfClass:[NSDictionary class]] &&
            ((NSDictionary *)object)[@"expDate"] != nil) {
            isLicence = YES;
        }
        if (!isLicence) return object;

        NSLog(@"[XoaInfoPatch] licence raw=%@", raw ?: @"(non-utf8)");

        NSMutableDictionary *dict = nil;
        if ([object isKindOfClass:[NSDictionary class]]) {
            dict = [object mutableCopy];
        } else if (raw != nil) {
            dict = XIPParseDelimited(data);
        }
        if (dict == nil) return object;

        XIPForceLicensed(dict);
        NSLog(@"[XoaInfoPatch] patched=%@", dict);
        return dict;
    } @catch (NSException *exception) {
        NSLog(@"[XoaInfoPatch] exception %@", exception);
        return object;
    }
}
%end

%ctor {
    NSLog(@"[XoaInfoPatch] loaded");
}
