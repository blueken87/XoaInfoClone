#import <Foundation/Foundation.h>
#import <substrate.h>

static void XIPForceLicensed(NSMutableDictionary *dict) {
    dict[@"code"] = @0;
    dict[@"success"] = @YES;
    dict[@"message"] = @"ok";
    dict[@"expDate"] = @"2099-12-31 23:59:59";
    dict[@"phase"] = @"9";
    dict[@"retention"] = @"99999";
    if (dict[@"deleteList"] == nil) dict[@"deleteList"] = @"";
    NSLog(@"[XoaInfoPatch] forced licensed response: %@", dict);
}

static NSDictionary *XIPParseDelimited(NSData *data) {
    NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (raw == nil) return nil;
    if ([raw rangeOfString:@"expDate"].location == NSNotFound &&
        [raw rangeOfString:@"licence"].location == NSNotFound) {
        return nil;
    }
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
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)object;
        if (dict[@"expDate"] != nil || (dict[@"code"] != nil && dict[@"message"] != nil)) {
            NSMutableDictionary *patched = [dict mutableCopy];
            XIPForceLicensed(patched);
            return patched;
        }
        return object;
    }
    NSDictionary *delimited = XIPParseDelimited(data);
    if (delimited != nil) {
        NSMutableDictionary *patched = [delimited mutableCopy];
        XIPForceLicensed(patched);
        return patched;
    }
    return object;
}
%end

%ctor {
    NSLog(@"[XoaInfoPatch] loaded");
}
