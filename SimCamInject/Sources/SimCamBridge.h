// SimCamInject/Sources/SimCamBridge.h
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface SimCamBridge : NSObject
@property (class, readonly) SimCamBridge *shared;
// atomic: escritas desde la sessionQueue de la app (fake_setDelegate/fake_addOutput) y leídas
// desde la cola de URLSession de CodeStreamClient (SimCamDeliverCode). atomic evita la carrera.
@property (atomic, weak) AVCaptureMetadataOutput *output;
@property (atomic, weak) id<AVCaptureMetadataOutputObjectsDelegate> delegate;
@property (atomic, strong, nullable) dispatch_queue_t delegateQueue;
@property (nonatomic, weak) CALayer *previewLayer;
@property (nonatomic, strong, nullable) CALayer *contentLayer;
// Cámara falsa por frames (CameraFeedShims.m): captura del delegate de vídeo. atomic porque se
// escriben desde la cola de setup de la app y se leen desde la cola del /stream (PreviewClient).
@property (atomic, weak) AVCaptureVideoDataOutput *videoOutput;
@property (atomic, weak) id videoDelegate;
@property (atomic, strong, nullable) dispatch_queue_t videoDelegateQueue;
@end

void SimCamInstallAVShims(void);
void SimCamInstallPreviewShim(void);
void SimCamInstallCameraShims(void);
// Entrega un frame (del /stream) al captureOutput de la app. La llama PreviewClient por cada frame.
void SimCamFeedFrame(CGImageRef img);

NS_ASSUME_NONNULL_END
