// SimCamInject/Sources/SimCamMetadataObject.h
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface SimCamMetadataObject : AVMetadataMachineReadableCodeObject
+ (instancetype)objectWithType:(AVMetadataObjectType)type stringValue:(NSString *)value;
@end
NS_ASSUME_NONNULL_END
