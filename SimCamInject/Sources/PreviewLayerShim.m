// SimCamInject/Sources/PreviewLayerShim.m
#import "SimCamBridge.h"
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

static IMP origPreviewInit;
static id shim_previewInit(id self, SEL _cmd, AVCaptureSession *session) {
    AVCaptureVideoPreviewLayer *layer =
        ((id(*)(id, SEL, AVCaptureSession *))origPreviewInit)(self, _cmd, session);
    CALayer *content = [CALayer layer];
    content.contentsGravity = kCAGravityResizeAspectFill;
    content.masksToBounds = YES;
    [layer addSublayer:content];
    SimCamBridge.shared.previewLayer = layer;
    SimCamBridge.shared.contentLayer = content;
    NSLog(@"[SimCamInject] preview layer enganchada");
    return layer;
}

void SimCamInstallPreviewShim(void) {
    Class cls = [AVCaptureVideoPreviewLayer class];
    Method m = class_getInstanceMethod(cls, @selector(initWithSession:));
    if (!m) { NSLog(@"[SimCamInject] sin initWithSession: en AVCaptureVideoPreviewLayer"); return; }
    origPreviewInit = method_setImplementation(m, (IMP)shim_previewInit);
}
