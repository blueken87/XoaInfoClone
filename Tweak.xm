#import <Foundation/Foundation.h>
#import <substrate.h>

static NSString *const kXIPSpoofedResponse =
    @"expDate:2099-12-31 23:59:59|<>|phase:9|<>|retention:99999|<>|deleteList:|<>|message:ok|<>|code:0|<>|encrypted:1234567890|<>|DataRun:|<>|version_run:1|<>|RunVersion:1";

static NSData *XIPSpoofedData(void) {
    static NSData *data = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        data = [kXIPSpoofedResponse dataUsingEncoding:NSUTF8StringEncoding];
    });
    return data;
}

static BOOL XIPContainsLicenceMarker(const void *bytes, NSUInteger length) {
    if (bytes == NULL || length < 8) return NO;
    static const char *markers[] = {
        "expDate:", "failed licence", "|<>|", "loginipX2.1", "redeemcode.php"
    };
    for (size_t m = 0; m < sizeof(markers) / sizeof(markers[0]); m++) {
        const char *needle = markers[m];
        size_t nlen = strlen(needle);
        if (nlen == 0 || nlen > length) continue;
        for (NSUInteger i = 0; i + nlen <= length; i++) {
            if (memcmp((const char *)bytes + i, needle, nlen) == 0) return YES;
        }
    }
    return NO;
}

static void XIPLog(NSString *message) {
    @try {
        NSString *path = @"/var/mobile/Library/Preferences/XoaInfoPatch.log";
        NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (fh) {
            [fh seekToEndOfFile];
            [fh writeData:data];
            [fh closeFile];
        } else {
            [data writeToFile:path atomically:NO];
        }
    } @catch (NSException *e) { }
}

%hook NSString

- (instancetype)initWithData:(NSData *)data encoding:(NSStringEncoding)encoding {
    if (XIPContainsLicenceMarker(data.bytes, data.length)) {
        XIPLog([NSString stringWithFormat:@"spoof NSString initWithData len=%lu", (unsigned long)data.length]);
        return [kXIPSpoofedResponse copy];
    }
    return %orig;
}

- (instancetype)initWithBytes:(const void *)bytes length:(NSUInteger)length encoding:(NSStringEncoding)encoding {
    if (XIPContainsLicenceMarker(bytes, length)) {
        XIPLog([NSString stringWithFormat:@"spoof NSString initWithBytes len=%lu", (unsigned long)length]);
        return [kXIPSpoofedResponse copy];
    }
    return %orig;
}

+ (instancetype)stringWithUTF8String:(const char *)nullTerminatedCString {
    if (nullTerminatedCString && XIPContainsLicenceMarker(nullTerminatedCString, strlen(nullTerminatedCString))) {
        XIPLog(@"spoof NSString stringWithUTF8String");
        return [kXIPSpoofedResponse copy];
    }
    return %orig;
}

+ (instancetype)stringWithCString:(const char *)cString encoding:(NSStringEncoding)enc {
    if (cString && XIPContainsLicenceMarker(cString, strlen(cString))) {
        XIPLog(@"spoof NSString stringWithCString");
        return [kXIPSpoofedResponse copy];
    }
    return %orig;
}

+ (instancetype)stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding {
    if (XIPContainsLicenceMarker(data.bytes, data.length)) {
        XIPLog(@"spoof NSString stringWithData");
        return [kXIPSpoofedResponse copy];
    }
    return %orig;
}

%end

%hook NSMutableData

- (void)appendData:(NSData *)otherData {
    if (XIPContainsLicenceMarker(otherData.bytes, otherData.length)) {
        XIPLog([NSString stringWithFormat:@"spoof NSMutableData appendData len=%lu", (unsigned long)otherData.length]);
        [self setLength:0];
        %orig(XIPSpoofedData());
        return;
    }
    %orig;
}

- (void)appendBytes:(const void *)bytes length:(NSUInteger)length {
    if (XIPContainsLicenceMarker(bytes, length)) {
        XIPLog([NSString stringWithFormat:@"spoof NSMutableData appendBytes len=%lu", (unsigned long)length]);
        [self setLength:0];
        NSData *spoofed = XIPSpoofedData();
        %orig(spoofed.bytes, spoofed.length);
        return;
    }
    %orig;
}

- (void)setData:(NSData *)data {
    if (XIPContainsLicenceMarker(data.bytes, data.length)) {
        XIPLog(@"spoof NSMutableData setData");
        %orig(XIPSpoofedData());
        return;
    }
    %orig;
}

%end

%ctor {
    XIPLog(@"loaded");
    NSLog(@"[XoaInfoPatch] loaded");
}