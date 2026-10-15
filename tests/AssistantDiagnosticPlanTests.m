#import <Foundation/Foundation.h>
#import "DYYYAssistantDiagnosticPlan.h"

int main(void) {
    @autoreleasepool {
        NSMutableArray *noise = [NSMutableArray array];
        for (NSUInteger i = 0; i < 12000; i++) {
            [noise addObject:@{@"name":[NSString stringWithFormat:@"_TtCStreakNoise%lu", (unsigned long)i], @"hasObjCMetadata":@NO}];
        }
        [noise addObjectsFromArray:@[
            @{@"name":@"AWEIMChatListZ", @"hasObjCMetadata":@YES},
            @{@"name":@"AWEIMChatListA", @"hasObjCMetadata":@YES},
            @{@"name":@"AWEIMChatListA", @"hasObjCMetadata":@YES}
        ]];
        NSArray *required = @[@"IESIMMessageSender", @"MissingTarget", @"ObservedDataSource", @"IESIMMessageSender"];
        NSArray *plan = [DYYYAssistantDiagnosticPlan selectedNamesFromCandidates:noise requiredNames:required supplementaryLimit:1];
        NSCAssert(plan.count == 4, @"必选接口不占补充预算，且应去重");
        NSCAssert([plan containsObject:@"IESIMMessageSender"] && [plan containsObject:@"ObservedDataSource"], @"不能被大批无方法Swift类挤掉");
        NSCAssert([plan containsObject:@"MissingTarget"], @"缺失目标必须保留查询状态");
        NSCAssert([plan.lastObject isEqualToString:@"AWEIMChatListA"], @"补充类型按确定性顺序选择");
        NSArray *reversePlan = [DYYYAssistantDiagnosticPlan selectedNamesFromCandidates:noise.reverseObjectEnumerator.allObjects requiredNames:required supplementaryLimit:1];
        NSCAssert([plan isEqualToArray:reversePlan], @"枚举顺序不得影响导出选择");
        NSArray *requiredOnly = [DYYYAssistantDiagnosticPlan selectedNamesFromCandidates:noise requiredNames:required supplementaryLimit:0];
        NSCAssert(requiredOnly.count == 3, @"补充预算为零仍要保留全部必选目标");
        NSCAssert([DYYYAssistantDiagnosticPlan.targetClassNames containsObject:@"AWEIMUserDBManager"], @"必须覆盖好友服务");
        NSLog(@"定向诊断选择测试通过");
    }
    return 0;
}
