// SimCamInject/Sources/SimCamDelivery.m
#import "SimCamDelivery.h"
#import "SimCamBridge.h"
#import "SimCamMetadataObject.h"

// El método del protocolo AVCaptureMetadataOutputObjectsDelegate tiene como selector ObjC
// `captureOutput:didOutputMetadataObjects:fromConnection:`. Swift lo presenta como
// `metadataOutput(_:didOutput:from:)` vía apinotes, pero el selector subyacente NO cambia
// (se mantiene `captureOutput:...` para no colisionar con el de sample buffer). Declaramos
// ambas variantes para que el compilador acepte las llamadas; en runtime usamos la que el
// delegate implemente realmente.
@protocol _SimCamMetadataDelegate <NSObject>
@optional
- (void)captureOutput:(AVCaptureOutput *)output
 didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects
       fromConnection:(AVCaptureConnection *)connection;
- (void)metadataOutput:(AVCaptureMetadataOutput *)output
 didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects
        fromConnection:(AVCaptureConnection *)connection;
@end

void SimCamDeliverCode(AVMetadataObjectType type, NSString *value) {
    SimCamBridge *b = SimCamBridge.shared;
    id<_SimCamMetadataDelegate> delegate = (id<_SimCamMetadataDelegate>)b.delegate;
    AVCaptureMetadataOutput *output = b.output;
    dispatch_queue_t queue = b.delegateQueue ?: dispatch_get_main_queue();
    if (!delegate || !output) { NSLog(@"[SimCamInject] sin delegate/output, descarto %@", value); return; }
    dispatch_async(queue, ^{
        SimCamMetadataObject *obj = [SimCamMetadataObject objectWithType:type stringValue:value];
        // la app ignora el `fromConnection:`; pasamos nil.
        if ([delegate respondsToSelector:@selector(captureOutput:didOutputMetadataObjects:fromConnection:)]) {
            [delegate captureOutput:output didOutputMetadataObjects:@[obj] fromConnection:nil];
            NSLog(@"[SimCamInject] entregado código (captureOutput:) type=%@ value=%@", type, value);
        } else if ([delegate respondsToSelector:@selector(metadataOutput:didOutputMetadataObjects:fromConnection:)]) {
            [delegate metadataOutput:output didOutputMetadataObjects:@[obj] fromConnection:nil];
            NSLog(@"[SimCamInject] entregado código (metadataOutput:) type=%@ value=%@", type, value);
        } else {
            NSLog(@"[SimCamInject] delegate no responde a ningún selector de metadata conocido, descartado: %@", value);
        }
    });
}
