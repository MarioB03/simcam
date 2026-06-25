// SimCamInject/Sources/AVFoundationShims.m
#import "SimCamBridge.h"
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>

// Helpers de swizzling -------------------------------------------------------
static void swizzleInstance(Class cls, SEL sel, IMP newImp, IMP *origStore) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { NSLog(@"[SimCamInject] sin método -%@ en %@", NSStringFromSelector(sel), cls); return; }
    *origStore = method_setImplementation(m, newImp);
}
static void swizzleClass(Class cls, SEL sel, IMP newImp, IMP *origStore) {
    Method m = class_getClassMethod(cls, sel);
    if (!m) { NSLog(@"[SimCamInject] sin método +%@ en %@", NSStringFromSelector(sel), cls); return; }
    *origStore = method_setImplementation(m, newImp);
}

// AVCaptureDevice ------------------------------------------------------------
static IMP origDefaultDevice;
static AVCaptureDevice *fake_defaultDevice(id self, SEL _cmd, AVMediaType type) {
    // Instancia "vacía" solo para pasar el `guard let device` de la app; no se usa para capturar.
    AVCaptureDevice *dev = class_createInstance([AVCaptureDevice class], 0);
    NSLog(@"[SimCamInject] AVCaptureDevice.default(for:) -> fake");
    return dev;
}
static AVAuthorizationStatus fake_authStatus(id self, SEL _cmd, AVMediaType type) {
    return AVAuthorizationStatusAuthorized;
}
static void fake_requestAccess(id self, SEL _cmd, AVMediaType type, void(^handler)(BOOL)) {
    if (handler) handler(YES);
}

// AVCaptureDeviceInput -------------------------------------------------------
static id fake_inputInit(id self, SEL _cmd, AVCaptureDevice *device, NSError **err) {
    if (err) *err = nil;
    return self; // no valida el device fake
}

// AVCaptureSession -----------------------------------------------------------
static BOOL fake_canAddInput(id self, SEL _cmd, id input)  { return YES; }
static BOOL fake_canAddOutput(id self, SEL _cmd, id output) { return YES; }
static void fake_addInput(id self, SEL _cmd, id input)  { /* no-op */ }
static IMP origAddOutput;
static void fake_addOutput(id self, SEL _cmd, id output) {
    if ([output isKindOfClass:[AVCaptureMetadataOutput class]]) {
        SimCamBridge.shared.output = output;
        NSLog(@"[SimCamInject] metadataOutput capturado");
    }
}
static void fake_startRunning(id self, SEL _cmd) { /* no-op */ }
static void fake_stopRunning(id self, SEL _cmd)  { /* no-op */ }

// AVCaptureDevice — focus/exposición (defensivos) ----------------------------
static BOOL fake_lockForConfiguration(id self, SEL _cmd, NSError **e) { if (e) *e = nil; return YES; }
static void fake_unlockForConfiguration(id self, SEL _cmd) { /* no-op */ }
static BOOL fake_isFocusPOISupported(id self, SEL _cmd) { return NO; }
static BOOL fake_isExposurePOISupported(id self, SEL _cmd) { return NO; }

// AVCaptureMetadataOutput ----------------------------------------------------
static void fake_setDelegate(id self, SEL _cmd, id delegate, dispatch_queue_t queue) {
    SimCamBridge.shared.output = self;
    SimCamBridge.shared.delegate = delegate;
    SimCamBridge.shared.delegateQueue = queue ?: dispatch_get_main_queue();
    NSLog(@"[SimCamInject] delegate capturado: %@", delegate);
}
static void fake_setTypes(id self, SEL _cmd, NSArray *types) { /* no-op: aceptamos cualquiera */ }

void SimCamInstallAVShims(void) {
    Class dev = [AVCaptureDevice class];
    swizzleClass(dev, @selector(defaultDeviceWithMediaType:), (IMP)fake_defaultDevice, &origDefaultDevice);
    swizzleClass(dev, @selector(authorizationStatusForMediaType:), (IMP)fake_authStatus, &(IMP){0});
    swizzleClass(dev, @selector(requestAccessForMediaType:completionHandler:), (IMP)fake_requestAccess, &(IMP){0});
    swizzleInstance(dev, @selector(lockForConfiguration:), (IMP)fake_lockForConfiguration, &(IMP){0});
    swizzleInstance(dev, @selector(unlockForConfiguration), (IMP)fake_unlockForConfiguration, &(IMP){0});
    swizzleInstance(dev, @selector(isFocusPointOfInterestSupported), (IMP)fake_isFocusPOISupported, &(IMP){0});
    swizzleInstance(dev, @selector(isExposurePointOfInterestSupported), (IMP)fake_isExposurePOISupported, &(IMP){0});

    Class input = [AVCaptureDeviceInput class];
    swizzleInstance(input, @selector(initWithDevice:error:), (IMP)fake_inputInit, &(IMP){0});

    Class session = [AVCaptureSession class];
    swizzleInstance(session, @selector(canAddInput:), (IMP)fake_canAddInput, &(IMP){0});
    swizzleInstance(session, @selector(canAddOutput:), (IMP)fake_canAddOutput, &(IMP){0});
    swizzleInstance(session, @selector(addInput:), (IMP)fake_addInput, &(IMP){0});
    swizzleInstance(session, @selector(addOutput:), (IMP)fake_addOutput, &origAddOutput);
    swizzleInstance(session, @selector(startRunning), (IMP)fake_startRunning, &(IMP){0});
    swizzleInstance(session, @selector(stopRunning), (IMP)fake_stopRunning, &(IMP){0});

    Class mo = [AVCaptureMetadataOutput class];
    swizzleInstance(mo, @selector(setMetadataObjectsDelegate:queue:), (IMP)fake_setDelegate, &(IMP){0});
    swizzleInstance(mo, @selector(setMetadataObjectTypes:), (IMP)fake_setTypes, &(IMP){0});

    NSLog(@"[SimCamInject] shims AVFoundation instalados");
}
