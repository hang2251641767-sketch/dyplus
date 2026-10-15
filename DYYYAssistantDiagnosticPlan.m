#import "DYYYAssistantDiagnosticPlan.h"

@implementation DYYYAssistantDiagnosticPlan

+ (NSArray<NSString *> *)targetClassNames {
    // 参考文件中的目标名称只用于查询接口，不链接或执行参考插件。
    return @[@"IESIMMessageSender", @"IESIMSendMessageModel", @"IESIMSendMessageResponse",
             @"IESIMConversationUtility", @"IESIMConversationDataManager", @"IESIMConversationListFetchContext",
             @"AWEIMUserDBManager", @"AWEIMChatListConsecutiveChatDaysHintProvider",
             @"AWEIMMessageConversation", @"AWEIMMessage", @"TIMXOConversationManager", @"TIMXOSendMessage",
             @"TIMXConversationORMCacheServiceIMPL", @"TIMXSendMessageRequestContext", @"TIMXMessageSenderSendMessageContext",
             @"AWEIMSendMessageContainer", @"AWEIMSendMessageContext", @"AWEIMSendMessageCallBackManager",
             @"AWEIMSendMessageCallBackTarget", @"AWEIMSendMessageCallBackResult",
             @"AWEIMStreakAchieveServerDataFetcher", @"AWEIMStreakAchieveServerDataRequest",
             @"AWEIMStreakServerDataPrefetchComponent", @"AWEUserModel", @"AWEAdaptorUserModel",
             @"AWEIMChatListCommonCell", @"AWEFollowListUserListViewModel", @"AWEFeedFriendsListCell",
             @"AWEIMCommentShareUserHorizontalSectionController", @"AWEIMCommentShareUserHorizontalCollectionViewCell",
             @"AWEIMShareAndForwardAwemeImpl", @"AWEIMShareAndForwardCommentShareImpl",
             @"IESIMShareAndForwardMessageSender", @"IESIMShareSenderRequest", @"AWEIMShareModel",
             @"AWEIMCommentShareModel", @"AWEIMShareIntentDataManager"];
}

+ (NSInteger)priorityForName:(NSString *)name {
    NSString *lower = name.lowercaseString;
    NSInteger score = 0;
    if ([name hasPrefix:@"AWEIM"] || [name hasPrefix:@"IESIM"] || [name hasPrefix:@"TIMX"]) score += 100;
    for (NSString *word in @[@"conversation", @"messagesender", @"sendmessage", @"chatlist", @"followlist", @"streak", @"shareuser", @"friendlist", @"contact", @"follower", @"mutual"]) {
        if ([lower containsString:word]) score += 100;
    }
    if ([lower containsString:@"swift"] || [name hasPrefix:@"_Tt"]) score = MAX(0, score - 50);
    return score;
}

+ (NSArray<NSString *> *)selectedNamesFromCandidates:(NSArray<NSDictionary *> *)candidates
                                     requiredNames:(NSArray<NSString *> *)requiredNames
                                supplementaryLimit:(NSUInteger)limit {
    // 必选目标不占补充预算；缺失目标也保留，以便导出明确的查询状态。
    NSMutableOrderedSet<NSString *> *selected = [NSMutableOrderedSet orderedSetWithArray:requiredNames];
    NSMutableDictionary<NSString *, NSNumber *> *scores = [NSMutableDictionary dictionary];
    for (NSDictionary *candidate in candidates) {
        NSString *name = candidate[@"name"];
        if (![name isKindOfClass:NSString.class] || [selected containsObject:name] || ![candidate[@"hasObjCMetadata"] boolValue]) continue;
        NSInteger score = [self priorityForName:name];
        if (score > 0) scores[name] = @(score);
    }
    NSArray *ranked = [scores.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSInteger left = [scores[a] integerValue], right = [scores[b] integerValue];
        if (left != right) return left > right ? NSOrderedAscending : NSOrderedDescending;
        return [a compare:b options:NSLiteralSearch];
    }];
    for (NSString *name in [ranked subarrayWithRange:NSMakeRange(0, MIN(limit, ranked.count))]) [selected addObject:name];
    return selected.array;
}
@end
