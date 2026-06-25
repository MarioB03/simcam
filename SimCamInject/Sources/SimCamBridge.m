// SimCamInject/Sources/SimCamBridge.m
#import "SimCamBridge.h"

@implementation SimCamBridge
+ (SimCamBridge *)shared {
    static SimCamBridge *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [SimCamBridge new]; });
    return s;
}
@end
