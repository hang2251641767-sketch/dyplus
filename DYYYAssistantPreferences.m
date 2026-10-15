#import "DYYYAssistantPreferences.h"
#import <dispatch/dispatch.h>

@interface DYYYAssistantPreferences ()
@property(nonatomic, strong) NSUserDefaults *defaults;
@end

@implementation DYYYAssistantPreferences

#pragma mark - 初始化

+ (instancetype)sharedStore {
    static DYYYAssistantPreferences *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[self alloc] initWithDefaults:NSUserDefaults.standardUserDefaults];
    });
    return store;
}

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) _defaults = defaults;
    return self;
}

#pragma mark - 计划草稿

- (NSString *)message {
    id value = [self.defaults objectForKey:@"DYYYAssistantStreakMessageV1"];
    return [value isKindOfClass:NSString.class] ? value : @"续火花🔥";
}

- (void)setMessage:(NSString *)message {
    NSString *trimmed = [message stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length > 0 && trimmed.length <= 500) {
        [self.defaults setObject:trimmed forKey:@"DYYYAssistantStreakMessageV1"];
    }
}

- (NSString *)timeString {
    id value = [self.defaults objectForKey:@"DYYYAssistantStreakTimeV1"];
    return [value isKindOfClass:NSString.class] ? value : @"09:00";
}

- (BOOL)setTimeString:(NSString *)time {
    NSRegularExpression *format = [NSRegularExpression regularExpressionWithPattern:@"^([01][0-9]|2[0-3]):[0-5][0-9]$" options:0 error:nil];
    if (![time isKindOfClass:NSString.class] || time.length != 5 ||
        [format numberOfMatchesInString:time options:0 range:NSMakeRange(0, time.length)] != 1) return NO;
    [self.defaults setObject:time forKey:@"DYYYAssistantStreakTimeV1"];
    return YES;
}

#pragma mark - 本地名单

- (NSString *)keyForList:(NSString *)list {
    if ([list isEqualToString:@"streak"]) return @"DYYYAssistantStreakContactsV1";
    if ([list isEqualToString:@"privacy"]) return @"DYYYAssistantPrivateContactsV1";
    return nil;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)contactsForList:(NSString *)list {
    NSString *key = [self keyForList:list];
    id value = key ? [self.defaults objectForKey:key] : nil;
    if (![value isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *result = [NSMutableArray array];
    for (id row in value) {
        if ([row isKindOfClass:NSDictionary.class] && [row[@"identifier"] isKindOfClass:NSString.class] &&
            [row[@"nickname"] isKindOfClass:NSString.class]) [result addObject:row];
    }
    return result;
}

- (BOOL)putIdentifier:(NSString *)identifier nickname:(NSString *)nickname inList:(NSString *)list {
    NSString *key = [self keyForList:list];
    NSString *uid = [identifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"].invertedSet;
    if (!key || !uid.length || uid.length > 256 || [uid rangeOfCharacterFromSet:allowed].location != NSNotFound) return NO;
    NSString *name = [nickname stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length > 80) return NO;
    NSMutableArray *rows = [[self contactsForList:list] mutableCopy];
    NSUInteger index = [rows indexOfObjectPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
        return [row[@"identifier"] isEqualToString:uid];
    }];
    NSDictionary *contact = @{@"identifier":uid, @"nickname":name.length ? name : uid};
    if (index != NSNotFound) rows[index] = contact;
    else [rows addObject:contact];
    [self.defaults setObject:rows forKey:key];
    return YES;
}

- (void)removeIdentifier:(NSString *)identifier fromList:(NSString *)list {
    NSString *key = [self keyForList:list];
    if (!key) return;
    NSMutableArray *rows = [[self contactsForList:list] mutableCopy];
    NSIndexSet *indices = [rows indexesOfObjectsPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
        return [row[@"identifier"] isEqualToString:identifier];
    }];
    [rows removeObjectsAtIndexes:indices];
    [self.defaults setObject:rows forKey:key];
}
@end
