// SimCamInject/Sources/CameraFeedShims.m
// Modo "cámara falsa por frames": SimCam entrega a la app los frames reales del host (/stream) a
// través de su AVCaptureVideoDataOutput, para que la APP corra SU PROPIA lógica (Vision, ML, lo
// que sea) sobre ellos. La app no se toca ni se conoce: es la emulación genérica de la cámara.
// Aislado del path de la app (AVFoundationShims.m, modo metadata-output). ARC.
#import "SimCamBridge.h"
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>

// Helpers de swizzling (réplica deliberada de AVFoundationShims.m, para no acoplar con el path la app).
static void swizzleClass(Class cls, SEL sel, IMP newImp, IMP *origStore) {
    Method m = class_getClassMethod(cls, sel);
    if (!m) { NSLog(@"[SimCamInject] sin método +%@ en %@", NSStringFromSelector(sel), cls); return; }
    *origStore = method_setImplementation(m, newImp);
}
static void swizzleInstance(Class cls, SEL sel, IMP newImp, IMP *origStore) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { NSLog(@"[SimCamInject] sin método -%@ en %@", NSStringFromSelector(sel), cls); return; }
    *origStore = method_setImplementation(m, newImp);
}

// --- Device fake: AVCaptureDevice.default(.builtInWideAngleCamera, for:.video, position:.back) -----
// Selector defaultDeviceWithDeviceType:mediaType:position:. Sin esto, una app que pida la cámara
// trasera recibe nil y aborta el setup.
static AVCaptureDevice *fake_defaultDevice3(id self, SEL _cmd,
                                            AVCaptureDeviceType type,
                                            AVMediaType mediaType,
                                            AVCaptureDevicePosition position) {
    NSLog(@"[SimCamInject] AVCaptureDevice.default(deviceType:for:position:) -> fake");
    return class_createInstance([AVCaptureDevice class], 0);
}

// --- Captura del sampleBufferDelegate de vídeo -------------------------------------------------
// -[AVCaptureVideoDataOutput setSampleBufferDelegate:queue:]. Guardamos (output, delegate, queue)
// para poder entregarle nosotros los frames del /stream.
static void fake_setSampleBufferDelegate(id self, SEL _cmd, id delegate, dispatch_queue_t queue) {
    SimCamBridge.shared.videoOutput = self;
    SimCamBridge.shared.videoDelegate = delegate;
    SimCamBridge.shared.videoDelegateQueue = queue ?: dispatch_get_main_queue();
    NSLog(@"[SimCamInject] sampleBufferDelegate capturado: %@", delegate);
}

// --- CGImage -> CVPixelBuffer (BGRA) -----------------------------------------------------------
static CVPixelBufferRef SimCamPixelBufferFromCGImage(CGImageRef img) {
    size_t w = CGImageGetWidth(img), h = CGImageGetHeight(img);
    if (w == 0 || h == 0) return NULL;
    CVPixelBufferRef pb = NULL;
    NSDictionary *attrs = @{ (id)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    if (CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                            (__bridge CFDictionaryRef)attrs, &pb) != kCVReturnSuccess || !pb) {
        return NULL;
    }
    CVPixelBufferLockBaseAddress(pb, 0);
    void *base = CVPixelBufferGetBaseAddress(pb);
    size_t bpr = CVPixelBufferGetBytesPerRow(pb);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(base, w, h, 8, bpr, cs,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    if (ctx) {
        CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), img);
        CGContextRelease(ctx);
    }
    CGColorSpaceRelease(cs);
    CVPixelBufferUnlockBaseAddress(pb, 0);
    return pb;
}

// --- Entrega de un frame a la app --------------------------------------------------------------
// Lo llama PreviewClient con cada frame decodificado del /stream. Construye un CMSampleBuffer y se
// lo entrega al captureOutput del delegate capturado; la app corre SU lógica sobre el frame.
// No-op mientras la app no haya registrado su sampleBufferDelegate.
void SimCamFeedFrame(CGImageRef img) {
    id delegate = SimCamBridge.shared.videoDelegate;
    dispatch_queue_t q = SimCamBridge.shared.videoDelegateQueue;
    AVCaptureVideoDataOutput *output = SimCamBridge.shared.videoOutput;
    if (!img || !delegate || !q) return;

    CVPixelBufferRef pb = SimCamPixelBufferFromCGImage(img);
    if (!pb) return;
    CMVideoFormatDescriptionRef fmt = NULL;
    if (CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pb, &fmt) != noErr || !fmt) {
        CVPixelBufferRelease(pb);
        return;
    }
    CMSampleBufferRef sb = NULL;
    CMSampleTimingInfo timing = { kCMTimeInvalid, kCMTimeZero, kCMTimeInvalid };
    OSStatus s = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pb, true, NULL, NULL,
                                                    fmt, &timing, &sb);
    CFRelease(fmt);
    CVPixelBufferRelease(pb);
    if (s != noErr || !sb) return;

    dispatch_async(q, ^{
        @try {
            if ([delegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
                [(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate
                    captureOutput:output didOutputSampleBuffer:sb fromConnection:nil];
            }
        } @catch (NSException *ex) {
            NSLog(@"[SimCamInject] excepción al entregar frame: %@", ex);
        }
        CFRelease(sb);
    });
}

void SimCamInstallCameraShims(void) {
    swizzleClass([AVCaptureDevice class], @selector(defaultDeviceWithDeviceType:mediaType:position:),
                 (IMP)fake_defaultDevice3, &(IMP){0});
    swizzleInstance([AVCaptureVideoDataOutput class], @selector(setSampleBufferDelegate:queue:),
                    (IMP)fake_setSampleBufferDelegate, &(IMP){0});
    NSLog(@"[SimCamInject] shims de cámara (frame-feed) instalados");
}
