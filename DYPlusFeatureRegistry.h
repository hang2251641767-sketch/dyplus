#import <Foundation/Foundation.h>

/// Central, fail-closed gate for newly refactored DYPlus modules.
/// Legacy DYYY hooks are deliberately not reported as verified by this class.
@interface DYPlusFeatureRegistry : NSObject

+ (BOOL)isTargetAppVersion;
+ (NSString *)currentAppVersion;
+ (BOOL)isMasterEnabled;
+ (BOOL)isFeatureEnabled:(NSString *)identifier;
+ (void)setFeature:(NSString *)identifier enabled:(BOOL)enabled;
+ (void)restoreSafeDefaults;
+ (NSArray<NSDictionary<NSString *, id> *> *)modules;

@end
