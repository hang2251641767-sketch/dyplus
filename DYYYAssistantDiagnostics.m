#import "DYYYAssistantDiagnostics.h"
#import "DYYYConstants.h"
#import "DYYYUtils.h"
#import "DYYYAssistantDiagnosticPlan.h"
#import <objc/runtime.h>

@interface DYYYAssistantDiagnostics ()
@property(nonatomic, strong) NSTimer *captureTimer;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *capturedLists;
@property(nonatomic, strong) NSMutableSet<NSDictionary *> *capturedKeys;
@property(nonatomic, assign) NSTimeInterval startedAt;
@property(nonatomic, assign) BOOL scanTruncated;
@property(nonatomic, assign) BOOL recordsTruncated;
@property(nonatomic, copy) NSString *stopReason;
@end

@implementation DYYYAssistantDiagnostics

#pragma mark - 类型元数据

+ (BOOL)isRelevantName:(NSString *)name {
    NSString *lower = name.lowercaseString;
    for (NSString *keyword in @[@"conversation", @"session", @"streak", @"spark", @"flame", @"fire", @"friend", @"follower", @"following", @"mutual", @"relation", @"shareuser", @"sharepanel", @"sharecontact", @"contact", @"chat", @"sendmessage", @"textmessage", @"immessage", @"messagecenter", @"inbox", @"messagelist"]) {
        if ([lower containsString:keyword]) return YES;
    }
    return [name isEqualToString:@"AWEUserModel"] || [name hasPrefix:@"BIM"] || [name hasPrefix:@"BDIM"] ||
           [name hasPrefix:@"TTIM"] || [name hasPrefix:@"AWEIM"];
}

+ (NSArray *)methodsForClass:(Class)cls {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableArray *rows = [NSMutableArray array];
    // 定向接口不截断方法列表；只记录签名，不执行任何私有方法。
    for (unsigned int i = 0; i < count; i++) {
        const char *encoding = method_getTypeEncoding(methods[i]);
        [rows addObject:@{@"selector":NSStringFromSelector(method_getName(methods[i])),
                          @"encoding":encoding ? @(encoding) : @""}];
    }
    free(methods);
    return rows;
}

+ (NSDictionary *)metadataForClass:(Class)cls {
    NSMutableArray *properties = [NSMutableArray array];
    unsigned int count = 0;
    objc_property_t *items = class_copyPropertyList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        const char *attributes = property_getAttributes(items[i]);
        [properties addObject:@{@"name":@(property_getName(items[i])), @"attributes":attributes ? @(attributes) : @""}];
    }
    free(items);
    NSMutableArray *ivars = [NSMutableArray array];
    Ivar *fields = class_copyIvarList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        const char *name = ivar_getName(fields[i]);
        const char *encoding = ivar_getTypeEncoding(fields[i]);
        [ivars addObject:@{@"name":name ? @(name) : @"", @"encoding":encoding ? @(encoding) : @""}];
    }
    free(fields);
    Class superclass = class_getSuperclass(cls);
    return @{@"class":NSStringFromClass(cls), @"superclass":superclass ? NSStringFromClass(superclass) : @"",
             @"instanceMethods":[self methodsForClass:cls], @"classMethods":[self methodsForClass:object_getClass(cls)],
             @"properties":properties, @"ivars":ivars};
}

#pragma mark - UIKit 类型快照

+ (NSString *)typeName:(id)object {
    return object ? NSStringFromClass(object_getClass(object)) : @"";
}

+ (NSDictionary *)viewSnapshot {
    NSAssert(NSThread.isMainThread, @"视图检查必须在主线程");
    NSMutableArray<UIView *> *queue = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:UIWindowScene.class]) {
            for (UIWindow *window in ((UIWindowScene *)scene).windows) if (!window.hidden) [queue addObject:window];
        }
    }
    NSMutableArray *rows = [NSMutableArray array];
    NSUInteger cursor = 0;
    BOOL truncated = NO;
    while (cursor < queue.count && cursor < 4000) {
        UIView *view = queue[cursor++];
        if (view.hidden || view.alpha < 0.01) continue;
        NSUInteger remaining = 4000 - MIN(queue.count, 4000UL);
        if (view.subviews.count > remaining) truncated = YES;
        if (remaining) [queue addObjectsFromArray:[view.subviews subarrayWithRange:NSMakeRange(0, MIN(remaining, view.subviews.count))]];
        UIWindow *window = view.window;
        if (!window || !CGRectIntersectsRect([view convertRect:view.bounds toView:window], window.bounds)) continue;
        NSString *kind = nil;
        id source = nil, delegate = nil;
        NSArray *cells = @[];
        if ([view isKindOfClass:UITableView.class]) {
            UITableView *table = (UITableView *)view;
            kind = @"table";
            source = table.dataSource;
            delegate = table.delegate;
            cells = table.visibleCells;
        } else if ([view isKindOfClass:UICollectionView.class]) {
            UICollectionView *collection = (UICollectionView *)view;
            kind = @"collection";
            source = collection.dataSource;
            delegate = collection.delegate;
            cells = collection.visibleCells;
        }
        if (!kind) continue;
        NSString *owner = @"";
        UIResponder *responder = view.nextResponder;
        for (NSUInteger depth = 0; responder && depth < 30; depth++, responder = responder.nextResponder) {
            if ([responder isKindOfClass:UIViewController.class]) { owner = [self typeName:responder]; break; }
        }
        NSMutableSet *cellTypes = [NSMutableSet set];
        for (UIView *cell in cells) [cellTypes addObject:[self typeName:cell]];
        [rows addObject:@{@"view":[self typeName:view], @"kind":kind, @"owner":owner,
                          @"dataSource":[self typeName:source], @"delegate":[self typeName:delegate],
                          @"visibleCellClasses":[cellTypes.allObjects sortedArrayUsingSelector:@selector(compare:)]}];
    }
    return @{@"lists":rows, @"scanTruncated":@(truncated)};
}

#pragma mark - 用户发起的限时页面采集

+ (instancetype)sharedRecorder {
    static DYYYAssistantDiagnostics *recorder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recorder = [[self alloc] init];
        recorder.capturedLists = [NSMutableArray array];
        recorder.capturedKeys = [NSMutableSet set];
        recorder.stopReason = @"尚未开始";
    });
    return recorder;
}

+ (BOOL)isCapturing { return self.sharedRecorder.captureTimer.isValid; }

+ (NSString *)captureStatus {
    DYYYAssistantDiagnostics *recorder = self.sharedRecorder;
    return [NSString stringWithFormat:@"%@ · %lu组列表类型", self.isCapturing ? @"采集中" : recorder.stopReason, (unsigned long)recorder.capturedLists.count];
}

- (void)stopWithReason:(NSString *)reason {
    [self.captureTimer invalidate];
    self.captureTimer = nil;
    self.stopReason = reason;
    [NSNotificationCenter.defaultCenter removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)didEnterBackground:(NSNotification *)notification { [self stopWithReason:@"进入后台，采集已停止"]; }

- (void)sample {
    if (NSProcessInfo.processInfo.systemUptime - self.startedAt >= 180) { [self stopWithReason:@"3分钟采集已结束"]; return; }
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    NSDictionary *snapshot = [self.class viewSnapshot];
    self.scanTruncated |= [snapshot[@"scanTruncated"] boolValue];
    for (NSDictionary *row in snapshot[@"lists"]) {
        if ([self.capturedKeys containsObject:row]) continue;
        if (self.capturedLists.count >= 300) { self.recordsTruncated = YES; [self stopWithReason:@"采集条数已达上限"]; break; }
        [self.capturedKeys addObject:row];
        [self.capturedLists addObject:row];
    }
}

+ (void)startCapture {
    NSAssert(NSThread.isMainThread, @"采集控制必须在主线程");
    [self clearCapture];
    DYYYAssistantDiagnostics *recorder = self.sharedRecorder;
    recorder.startedAt = NSProcessInfo.processInfo.systemUptime;
    recorder.stopReason = @"采集中";
    [NSNotificationCenter.defaultCenter addObserver:recorder selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    __weak DYYYAssistantDiagnostics *weakRecorder = recorder;
    recorder.captureTimer = [NSTimer timerWithTimeInterval:1.5 repeats:YES block:^(__unused NSTimer *timer) { [weakRecorder sample]; }];
    [NSRunLoop.mainRunLoop addTimer:recorder.captureTimer forMode:NSRunLoopCommonModes];
    [recorder sample];
}

+ (void)stopCapture { [self.sharedRecorder stopWithReason:@"已停止采集"]; }

+ (void)clearCapture {
    DYYYAssistantDiagnostics *recorder = self.sharedRecorder;
    [recorder stopWithReason:@"尚未开始"];
    [recorder.capturedLists removeAllObjects];
    [recorder.capturedKeys removeAllObjects];
    recorder.scanTruncated = NO;
    recorder.recordsTruncated = NO;
}

- (void)dealloc {
    [_captureTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - 手动导出

+ (BOOL)hasObjCMetadata:(Class)cls {
    unsigned int instanceCount = 0, classCount = 0;
    Method *instanceMethods = class_copyMethodList(cls, &instanceCount);
    Method *classMethods = class_copyMethodList(object_getClass(cls), &classCount);
    free(instanceMethods);
    free(classMethods);
    return instanceCount > 0 || classCount > 0;
}

+ (NSArray<NSString *> *)relatedNames:(NSDictionary *)metadata {
    NSMutableOrderedSet *names = [NSMutableOrderedSet orderedSet];
    if ([metadata[@"superclass"] length]) [names addObject:metadata[@"superclass"]];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"@\"([^\"<]+)" options:0 error:nil];
    for (NSString *key in @[@"properties", @"ivars"]) {
        for (NSDictionary *field in metadata[key]) {
            NSString *encoding = field[@"attributes"] ?: field[@"encoding"] ?: @"";
            NSTextCheckingResult *match = [expression firstMatchInString:encoding options:0 range:NSMakeRange(0, encoding.length)];
            if (match.numberOfRanges > 1) [names addObject:[encoding substringWithRange:[match rangeAtIndex:1]]];
        }
    }
    return names.array;
}

+ (void)exportFromController:(UIViewController *)controller completion:(void (^)(void))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self exportFromController:controller completion:completion]; });
        return;
    }
    NSDictionary *currentSnapshot = [self viewSnapshot];
    if (self.isCapturing) { [self.sharedRecorder sample]; [self stopCapture]; }
    NSArray *captured = [self.sharedRecorder.capturedLists copy];
    NSArray *views = currentSnapshot[@"lists"];
    NSDictionary *capture = @{@"status":self.captureStatus, @"recordCount":@(captured.count),
                              @"viewScanTruncated":@(self.sharedRecorder.scanTruncated),
                              @"recordLimitReached":@(self.sharedRecorder.recordsTruncated)};
    NSDictionary *version = @{@"appVersion":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"未知",
                              @"appBuild":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"未知",
                              @"systemVersion":UIDevice.currentDevice.systemVersion, @"pluginVersion":DYYY_VERSION};
    __weak UIViewController *weakController = controller;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray *classes = [NSMutableArray array];
        NSMutableSet *included = [NSMutableSet set];
        NSMutableDictionary<NSString *, id> *available = [NSMutableDictionary dictionary];
        NSMutableArray *candidates = [NSMutableArray array];
        NSMutableArray *classIndex = [NSMutableArray array];
        unsigned int count = 0;
        Class *loaded = objc_copyClassList(&count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *name = NSStringFromClass(loaded[i]);
            const char *image = class_getImageName(loaded[i]);
            NSString *imagePath = image ? @(image) : @"";
            if (![imagePath hasPrefix:NSBundle.mainBundle.bundlePath]) continue;
            available[name] = loaded[i];
            if ([self isRelevantName:name] || [DYYYAssistantDiagnosticPlan priorityForName:name] > 0) [classIndex addObject:name];
            if ([DYYYAssistantDiagnosticPlan priorityForName:name] > 0) {
                [candidates addObject:@{@"name":name, @"hasObjCMetadata":@([self hasObjCMetadata:loaded[i]])}];
            }
        }
        NSMutableOrderedSet<NSString *> *required = [NSMutableOrderedSet orderedSetWithArray:DYYYAssistantDiagnosticPlan.targetClassNames];
        for (NSDictionary *row in [captured arrayByAddingObjectsFromArray:views]) {
            for (NSString *key in @[@"view", @"dataSource", @"delegate", @"owner"]) {
                if ([row[key] length]) [required addObject:row[key]];
            }
            [required addObjectsFromArray:row[@"visibleCellClasses"] ?: @[]];
        }
        NSMutableArray *targetLookup = [NSMutableArray array];
        for (NSString *name in DYYYAssistantDiagnosticPlan.targetClassNames) {
            Class cls = (Class)available[name] ?: objc_lookUpClass(name.UTF8String);
            [targetLookup addObject:@{@"class":name, @"foundAtExport":@(cls != Nil)}];
        }
        NSArray *planned = [DYYYAssistantDiagnosticPlan selectedNamesFromCandidates:candidates requiredNames:required.array supplementaryLimit:150];
        NSMutableArray *pending = [required.array mutableCopy];
        NSMutableSet *scheduled = [NSMutableSet setWithArray:pending];
        NSUInteger cursor = 0, relatedAdded = 0;
        BOOL relatedLimited = NO;
        while (cursor < pending.count) {
            NSString *name = pending[cursor++];
            Class cls = (Class)available[name] ?: objc_lookUpClass(name.UTF8String);
            if (!cls || [included containsObject:name]) continue;
            NSMutableDictionary *metadata = [[self metadataForClass:cls] mutableCopy];
            metadata[@"selection"] = [required containsObject:name] ? @"required" : @"related";
            [classes addObject:metadata];
            [included addObject:name];
            for (NSString *related in [self relatedNames:metadata]) {
                if (!available[related] || [scheduled containsObject:related]) continue;
                if (relatedAdded >= 600) { relatedLimited = YES; continue; }
                [pending addObject:related];
                [scheduled addObject:related];
                relatedAdded++;
            }
        }
        NSUInteger eligibleSupplementary = 0;
        for (NSDictionary *candidate in candidates) {
            if ([candidate[@"hasObjCMetadata"] boolValue] && ![required containsObject:candidate[@"name"]]) eligibleSupplementary++;
        }
        for (NSString *name in planned) {
            if ([included containsObject:name] || !available[name]) continue;
            NSMutableDictionary *metadata = [[self metadataForClass:(Class)available[name]] mutableCopy];
            metadata[@"selection"] = @"supplementary";
            [classes addObject:metadata];
            [included addObject:name];
        }
        free(loaded);
        NSDictionary *report = @{@"schema":@2, @"metadataOnly":@YES, @"version":version,
                                 @"targetLookup":targetLookup, @"requiredMetadataTruncated":@NO,
                                 @"relatedMetadataLimited":@(relatedLimited), @"supplementarySelectionLimited":@(eligibleSupplementary > 150),
                                 @"candidateClassIndex":[classIndex sortedArrayUsingSelector:@selector(compare:)],
                                 @"classNameIndexTruncated":@NO, @"capture":capture,
                                 @"capturedListViewTypes":captured, @"listViewTypes":views,
                                 @"currentViewScanTruncated":currentSnapshot[@"scanTruncated"], @"interfaces":classes};
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&error];
        NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"DouyinAssistantPLUS-interfaces-v2.json"]];
        BOOL saved = data && [data writeToURL:url options:NSDataWritingAtomic error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
            UIViewController *presenter = weakController;
            if (!saved || !presenter.view.window) {
                [DYYYUtils showToast:saved ? @"页面已关闭，请重新导出" : @"诊断导出失败，请重试"];
                return;
            }
            UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
            share.popoverPresentationController.sourceView = presenter.view;
            share.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), 80, 1, 1);
            [presenter presentViewController:share animated:YES completion:nil];
        });
    });
}
@end
