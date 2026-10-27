#import <Foundation/Foundation.h>
#import <substrate.h>
#import <objc/runtime.h>

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

static BOOL XIPIsLicenceRequest(NSURLRequest *request) {
    NSString *url = request.URL.absoluteString.lowercaseString;
    if (url.length == 0) return NO;
    return [url containsString:@"loginip"] || [url containsString:@"redeemcode"] ||
           [url containsString:@"xoainfo"];
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

@interface XIPConnectionProxy : NSProxy
@property (nonatomic, weak) id originalDelegate;
@property (nonatomic, strong) NSMutableData *accumulatedData;
@end

@implementation XIPConnectionProxy

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(connection:didReceiveResponse:) ||
        aSelector == @selector(connection:didReceiveData:) ||
        aSelector == @selector(connectionDidFinishLoading:) ||
        aSelector == @selector(connection:didFailWithError:)) {
        return YES;
    }
    return [self.originalDelegate respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSMethodSignature *sig = [self.originalDelegate methodSignatureForSelector:sel];
    if (sig) return sig;
    return [NSMethodSignature signatureWithObjCTypes:"v@:@"];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if (self.originalDelegate) {
        [invocation invokeWithTarget:self.originalDelegate];
    }
}

- (id)forwardingTargetForSelector:(SEL)sel {
    return self.originalDelegate;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.accumulatedData setLength:0];
    if ([self.originalDelegate respondsToSelector:@selector(connection:didReceiveResponse:)]) {
        [self.originalDelegate connection:connection didReceiveResponse:response];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (data) [self.accumulatedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSData *payload = self.accumulatedData;
    if (XIPContainsLicenceMarker(payload.bytes, payload.length)) {
        XIPLog([NSString stringWithFormat:@"proxy spoof licence response len=%lu", (unsigned long)payload.length]);
        payload = XIPSpoofedData();
    } else {
        XIPLog([NSString stringWithFormat:@"proxy pass-through len=%lu", (unsigned long)payload.length]);
    }

    if ([self.originalDelegate respondsToSelector:@selector(connection:didReceiveData:)]) {
        [self.originalDelegate connection:connection didReceiveData:payload];
    }
    if ([self.originalDelegate respondsToSelector:@selector(connectionDidFinishLoading:)]) {
        [self.originalDelegate connectionDidFinishLoading:connection];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if ([self.originalDelegate respondsToSelector:@selector(connection:didFailWithError:)]) {
        [self.originalDelegate connection:connection didFailWithError:error];
    }
}

@end

static char kXIPProxyKey;

%hook NSURLConnection

- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    return [self initWithRequest:request delegate:delegate startImmediately:YES];
}

- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately {
    id realDelegate = delegate;
    if (delegate && XIPIsLicenceRequest(request)) {
        XIPConnectionProxy *proxy = [XIPConnectionProxy alloc];
        proxy.originalDelegate = delegate;
        proxy.accumulatedData = [NSMutableData data];
        realDelegate = proxy;
        objc_setAssociatedObject(self, &kXIPProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        XIPLog(@"proxy installed for licence request");
    }
    return %orig(request, realDelegate, startImmediately);
}

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    NSData *data = %orig;
    if (XIPIsLicenceRequest(request) && XIPContainsLicenceMarker(data.bytes, data.length)) {
        XIPLog([NSString stringWithFormat:@"sync spoof licence response len=%lu", (unsigned long)data.length]);
        return XIPSpoofedData();
    }
    return data;
}

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    // Route through hooked initializer path by creating manually.
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
    return connection;
}

%end

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

%end

%ctor {
    XIPLog(@"loaded");
    NSLog(@"[XoaInfoPatch] loaded");
}
EOF