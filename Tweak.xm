#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>

static const NSTimeInterval kShift = -7 * 24 * 60 * 60;

%hook NSDate
+ (NSDate *)date {
    NSDate *d = %orig;
    return [d dateByAddingTimeInterval:kShift];
}
+ (NSDate *)now {
    NSDate *d = %orig;
    return [d dateByAddingTimeInterval:kShift];
}
%end

static CFAbsoluteTime (*orig_CFAbsoluteTimeGetCurrent)(void);
static CFAbsoluteTime new_CFAbsoluteTimeGetCurrent(void) {
    return orig_CFAbsoluteTimeGetCurrent() + kShift;
}

%ctor {
    void *sym = dlsym(RTLD_DEFAULT, "CFAbsoluteTimeGetCurrent");
    if (sym) MSHookFunction(sym, (void *)new_CFAbsoluteTimeGetCurrent, (void **)&orig_CFAbsoluteTimeGetCurrent);
    NSLog(@"[XoaInfoPatch] time shift loaded");
}
