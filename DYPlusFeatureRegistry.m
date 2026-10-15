#import "DYPlusFeatureRegistry.h"

static NSString *const kDYPlusMasterKey = @"DYPlusMasterEnabled";
static NSString *const kDYPlusTargetVersion = @"40.3.0";

@implementation DYPlusFeatureRegistry

+ (NSArray<NSDictionary<NSString *, id> *> *)modules {
    return @[
        @{ @"id" : @"DYPlusModuleSettings", @"title" : @"设置入口", @"detail" : @"模块待迁移；当前不控制历史设置入口" },
        @{ @"id" : @"DYPlusModuleUI", @"title" : @"界面调整", @"detail" : @"仅为后续 UI Hook 预留；默认关闭" },
        @{ @"id" : @"DYPlusModulePlayback", @"title" : @"播放控制", @"detail" : @"仅为后续播放 Hook 预留；默认关闭" },
        @{ @"id" : @"DYPlusModuleMedia", @"title" : @"媒体保存", @"detail" : @"仅为后续保存流程预留；默认关闭" },
        @{ @"id" : @"DYPlusModuleFilters", @"title" : @"过滤与屏蔽", @"detail" : @"仅为后续过滤 Hook 预留；默认关闭" }
    ];
}

+ (BOOL)isTargetAppVersion {
    return [[self currentAppVersion] isEqualToString:kDYPlusTargetVersion];
}

+ (NSString *)currentAppVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"未知";
}

+ (BOOL)isMasterEnabled {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults objectForKey:kDYPlusMasterKey]) {
        return NO; // New builds start in safe mode.
    }
    return [defaults boolForKey:kDYPlusMasterKey];
}

+ (BOOL)isFeatureEnabled:(NSString *)identifier {
    if (![self isMasterEnabled] || ![self isTargetAppVersion]) {
        return NO;
    }
    return [NSUserDefaults.standardUserDefaults boolForKey:identifier];
}

+ (void)setFeature:(NSString *)identifier enabled:(BOOL)enabled {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:identifier];
    [NSUserDefaults.standardUserDefaults synchronize];
}

+ (void)restoreSafeDefaults {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:NO forKey:kDYPlusMasterKey];
    for (NSDictionary *module in self.modules) {
        [defaults setBool:NO forKey:module[@"id"]];
    }
    [defaults synchronize];
}

@end
