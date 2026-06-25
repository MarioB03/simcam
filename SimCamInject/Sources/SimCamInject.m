// SimCamInject/Sources/SimCamInject.m
#import <Foundation/Foundation.h>
#import "SimCamBridge.h"
#import "SimCamDelivery.h"
#import "CodeStreamClient.h"
#import "PreviewClient.h"

static CodeStreamClient *gCodeClient;
static PreviewClient *gPreviewClient;

@interface SimCamInject : NSObject
@end

@implementation SimCamInject
+ (void)load {
    NSLog(@"[SimCamInject] dylib cargada (pid=%d)", getpid());
    SimCamInstallAVShims();
    SimCamInstallCameraShims();
    gCodeClient = [CodeStreamClient new];
    [gCodeClient start];
    SimCamInstallPreviewShim();
    gPreviewClient = [PreviewClient new];
    [gPreviewClient start];
}
@end
