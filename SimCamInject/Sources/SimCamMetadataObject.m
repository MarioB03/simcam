// SimCamInject/Sources/SimCamMetadataObject.m
// OJO: compilado con -fno-objc-arc (ver project.yml). El objeto se crea con
// class_createInstance (sin el init privado del padre), por eso gestionamos retain a mano.
#import "SimCamMetadataObject.h"
#import <objc/runtime.h>

@implementation SimCamMetadataObject {
    AVMetadataObjectType _typeOverride;
    NSString *_stringOverride;
}
+ (instancetype)objectWithType:(AVMetadataObjectType)type stringValue:(NSString *)value {
    SimCamMetadataObject *o = class_createInstance(self, 0);
    o->_typeOverride = [type retain];
    o->_stringOverride = [value retain];
    return o;
}
- (NSString *)stringValue { return _stringOverride; }
- (AVMetadataObjectType)type { return _typeOverride; }
- (NSArray<NSValue *> *)corners { return @[]; }
- (void)dealloc { [_typeOverride release]; [_stringOverride release]; [super dealloc]; }
@end
