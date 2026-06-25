// SimCamInject/Sources/CodeStreamClient.m
#import "CodeStreamClient.h"
#import "SimCamDelivery.h"
#import <AVFoundation/AVFoundation.h>

@interface CodeStreamClient () <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableData *buffer;
@end

@implementation CodeStreamClient

- (void)start {
    self.buffer = [NSMutableData data];
    NSURLSessionConfiguration *cfg = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    cfg.timeoutIntervalForRequest = 0; // streaming
    self.session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
    [self connect];
}

- (void)connect {
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:8474/codes"];
    [[self.session dataTaskWithURL:url] resume];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    [self.buffer appendData:data];
    [self drain];
}

- (void)drain {
    NSString *text = [[NSString alloc] initWithData:self.buffer encoding:NSUTF8StringEncoding];
    if (!text) return;
    NSArray<NSString *> *events = [text componentsSeparatedByString:@"\n\n"];
    // El ultimo elemento puede ser parcial: lo conservamos en el buffer.
    for (NSUInteger i = 0; i + 1 < events.count; i++) {
        NSString *line = events[i];
        if (![line hasPrefix:@"data: "]) continue;
        NSString *jsonStr = [line substringFromIndex:6];
        NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        NSString *type = obj[@"type"], *value = obj[@"stringValue"];
        if (type && value) SimCamDeliverCode(type, value);
    }
    NSString *tail = events.lastObject ?: @"";
    self.buffer = [[tail dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"[SimCamInject] /codes desconectado (%@); reintento en 1s", error.localizedDescription);
    self.buffer = [NSMutableData data];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self connect]; });
}

@end
