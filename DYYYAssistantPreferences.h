#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 扩展模块的本地配置草稿。不承担账号读取、消息发送或列表 Hook。
@interface DYYYAssistantPreferences : NSObject
+ (instancetype)sharedStore;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
@property(nonatomic, copy) NSString *message;
@property(nonatomic, readonly, copy) NSString *timeString;
- (BOOL)setTimeString:(NSString *)time;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)contactsForList:(NSString *)list;
- (BOOL)putIdentifier:(NSString *)identifier nickname:(NSString *)nickname inList:(NSString *)list;
- (void)removeIdentifier:(NSString *)identifier fromList:(NSString *)list;
@end

NS_ASSUME_NONNULL_END
