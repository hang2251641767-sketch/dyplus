#import <Foundation/Foundation.h>
#import "DYYYAssistantPreferences.h"

int main(void) {
    @autoreleasepool {
        NSString *suite = [@"com.dyplus.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        DYYYAssistantPreferences *store = [[DYYYAssistantPreferences alloc] initWithDefaults:defaults];
        NSCAssert([store.timeString isEqualToString:@"09:00"], @"默认时间错误");
        NSCAssert([store setTimeString:@"23:59"], @"有效时间应被接受");
        for (NSString *invalid in @[@"24:00", @"09:60", @"9:00", @"-1:00", @"09:00\n"]) {
            NSCAssert(![store setTimeString:invalid], @"无效时间不能覆盖计划");
        }
        NSCAssert([store.timeString isEqualToString:@"23:59"], @"无效输入破坏了原计划");
        store.message = @"自定义内容";
        store.message = @"   ";
        NSCAssert([store.message isEqualToString:@"自定义内容"], @"空消息不能覆盖内容");
        NSCAssert([store putIdentifier:@"uid_123" nickname:@"甲" inList:@"streak"], @"应允许手动添加");
        NSCAssert([store putIdentifier:@"uid_123" nickname:@"新备注" inList:@"streak"], @"应允许修改备注");
        NSCAssert([store contactsForList:@"streak"].count == 1, @"重复添加必须去重");
        NSCAssert([[store contactsForList:@"streak"].firstObject[@"nickname"] isEqualToString:@"新备注"], @"更新备注错误");
        NSCAssert(![store putIdentifier:@"包含 空格" nickname:@"昵称" inList:@"streak"], @"不能把昵称当UID");
        NSCAssert(![store putIdentifier:@"uid" nickname:@"昵称" inList:@"unknown"], @"不能写入未知名单");
        NSCAssert([store putIdentifier:@"uid_123" nickname:@"甲" inList:@"privacy"], @"应允许添加密友");
        [store removeIdentifier:@"uid_123" fromList:@"streak"];
        NSCAssert([store contactsForList:@"streak"].count == 0, @"移除好友错误");
        NSCAssert([store contactsForList:@"privacy"].count == 1, @"两个名单必须独立");
        DYYYAssistantPreferences *reloaded = [[DYYYAssistantPreferences alloc] initWithDefaults:defaults];
        NSCAssert([reloaded.timeString isEqualToString:@"23:59"], @"重建配置后时间未保存");
        NSCAssert([reloaded contactsForList:@"privacy"].count == 1, @"重建配置后名单未保存");
        [defaults removePersistentDomainForName:suite];
        NSLog(@"助手配置测试通过");
    }
    return 0;
}
