// SimCamInject/Sources/PreviewClient.m
// Consume /stream. URLSession desmultiplexa multipart/x-mixed-replace: cada parte llega
// como una "respuesta" image/jpeg seguida de sus bytes. Acumulamos por parte y decodificamos
// en la frontera de la siguiente parte (mismo patrón que SimulatorCameraClient del SPM).
#import "PreviewClient.h"
#import "SimCamBridge.h"
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>

@interface PreviewClient () <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableData *part;
@end

@implementation PreviewClient

- (void)start {
    self.part = [NSMutableData data];
    NSURLSessionConfiguration *cfg = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    cfg.timeoutIntervalForRequest = 0;
    self.session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
    [self connect];
}

- (void)connect {
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:8474/stream"];
    [[self.session dataTaskWithURL:url] resume];
}

- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t
  didReceiveResponse:(NSURLResponse *)r completionHandler:(void (^)(NSURLSessionResponseDisposition))h {
    [self flush];               // nueva parte: cierra la anterior
    h(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)data {
    [self.part appendData:data];
}

- (void)flush {
    if (self.part.length == 0) return;
    NSData *jpeg = self.part; self.part = [NSMutableData data];
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)jpeg, NULL);
    if (!src) return;
    CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, NULL);
    CFRelease(src);
    if (!img) return;
    SimCamFeedFrame(img); // cámara falsa: este mismo frame se entrega al captureOutput de la app
    dispatch_async(dispatch_get_main_queue(), ^{
        CALayer *content = SimCamBridge.shared.contentLayer;
        CALayer *preview = SimCamBridge.shared.previewLayer;
        if (content && preview) {
            [CATransaction begin]; [CATransaction setDisableActions:YES];
            content.frame = preview.bounds;
            content.contents = (__bridge id)img;
            [CATransaction commit];
        }
        CGImageRelease(img); // SIEMPRE dentro del bloque: si los layers son nil no se asigna a
                             // contents, pero el +1 del Create se libera igual (sin leak ni doble-release).
    });
}

- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)e {
    [self flush]; // no perder la última parte si el host cerró la conexión limpiamente
    self.part = [NSMutableData data];
    NSLog(@"[SimCamInject] /stream desconectado (%@); reintento en 1s", e.localizedDescription);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self connect]; });
}

@end
