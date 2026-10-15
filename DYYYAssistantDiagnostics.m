#import "DYYYAssistantDiagnostics.h"
#import "DYYYConstants.h"
#import "DYYYUtils.h"
#import "DYYYAssistantDiagnosticPlan.h"
#import "DYYYAssistantRuntimeInspector.h"
#import "DYYYAssistantDiagnosticArchive.h"
#import <objc/runtime.h>

@interface DYYYAssistantDiagnostics ()
@property(nonatomic, strong) NSTimer *captureTimer;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *capturedLists;
@property(nonatomic, strong) NSMutableSet<NSDictionary *> *capturedKeys;
@property(nonatomic, assign) NSTimeInterval startedAt;
@property(nonatomic, assign) BOOL scanTruncated;
@property(nonatomic, assign) BOOL recordsTruncated;
@property(nonatomic, copy) NSString *stopReason;
@property(nonatomic, assign) BOOL exportInProgress;
@end

@implementation DYYYAssistantDiagnostics

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

+ (DYYYAssistantDiagnostics *)sharedRecorder {
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

#pragma mark - 分阶段保存与文件出口

+ (DYYYAssistantDiagnosticArchive *)archive {
    NSURL *base = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    if (!base) base = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    return [[DYYYAssistantDiagnosticArchive alloc] initWithDirectory:[base URLByAppendingPathComponent:@"AssistantPLUSDiagnostics" isDirectory:YES]];
}

+ (NSString *)exportStatus {
    NSDictionary *state = self.archive.lastStage;
    NSString *stage = [state[@"stage"] isKindOfClass:NSString.class] ? state[@"stage"] : @"尚未生成";
    NSString *name = [state[@"class"] isKindOfClass:NSString.class] ? state[@"class"] : @"";
    return name.length ? [NSString stringWithFormat:@"%@ · %@", stage, name] : stage;
}

+ (void)saveExistingFromController:(UIViewController *)controller {
    NSAssert(NSThread.isMainThread, @"文件选择器必须在主线程");
    if (self.sharedRecorder.exportInProgress) { [DYYYUtils showToast:@"请等待生成结束"]; return; }
    DYYYAssistantDiagnosticArchive *archive = self.archive;
    if (!archive.hasReport) { [DYYYUtils showToast:@"尚无诊断文件，请先生成"]; return; }
    if (!controller.view.window || controller.presentedViewController) { [DYYYUtils showToast:@"页面暂不可用，请稍后重试"]; return; }
    NSMutableArray *urls = [NSMutableArray arrayWithObject:archive.reportURL];
    if ([NSFileManager.defaultManager fileExistsAtPath:archive.stateURL.path]) [urls addObject:archive.stateURL];
    // 独立的系统文件保存入口，不自动调用分享扩展。
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:urls asCopy:YES];
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [controller presentViewController:picker animated:YES completion:nil];
}

+ (void)exportFromController:(UIViewController *)controller completion:(void (^)(void))completion {
    [self generateSnapshotOnly:NO completion:completion];
}

+ (void)saveSnapshotOnlyWithCompletion:(void (^)(void))completion {
    [self generateSnapshotOnly:YES completion:completion];
}

+ (void)generateSnapshotOnly:(BOOL)snapshotOnly completion:(void (^)(void))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self generateSnapshotOnly:snapshotOnly completion:completion]; });
        return;
    }
    DYYYAssistantDiagnostics *recorder = self.sharedRecorder;
    if (recorder.exportInProgress) { if (completion) completion(); [DYYYUtils showToast:@"正在生成，请稍候"]; return; }
    recorder.exportInProgress = YES;
    // 停止后只复制内存记录，不在按钮点击时重新遍历UIKit视图。
    if (self.isCapturing) [self stopCapture];
    NSArray *captured = [recorder.capturedLists copy];
    NSDictionary *capture = @{@"status":self.captureStatus, @"recordCount":@(captured.count),
                              @"viewScanTruncated":@(recorder.scanTruncated), @"recordLimitReached":@(recorder.recordsTruncated)};
    NSDictionary *version = @{@"appVersion":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"未知",
                              @"appBuild":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"未知",
                              @"systemVersion":UIDevice.currentDevice.systemVersion, @"pluginVersion":DYYY_VERSION};
    DYYYAssistantDiagnosticArchive *archive = self.archive;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            BOOL saved = NO, complete = NO;
            NSString *failure = nil;
            NSError *error = nil;
            NSMutableArray *interfaces = [NSMutableArray array];
            NSMutableDictionary *report = [@{@"schema":@3, @"metadataOnly":@YES, @"complete":@NO,
                @"mode":snapshotOnly ? @"snapshot-only" : @"safe-targeted",
                @"version":version, @"capture":capture, @"capturedListViewTypes":captured,
                @"broadClassScanEnabled":@NO, @"relatedTypeExpansionEnabled":@NO, @"interfaces":interfaces} mutableCopy];
            @try {
                // 在检查第一个Class前，先保存能独立取回的轻量快照。
                saved = [archive saveReport:report error:&error];
                if (!saved) failure = @"snapshot-write-failed";
                if (saved && ![archive saveStage:@"snapshot-saved" className:@"" error:&error]) failure = @"stage-write-failed";
                if (saved && !failure && !snapshotOnly) {
                    NSMutableOrderedSet *required = [NSMutableOrderedSet orderedSetWithArray:DYYYAssistantDiagnosticPlan.targetClassNames];
                    for (NSDictionary *row in captured) {
                        for (NSString *key in @[@"view", @"dataSource", @"delegate", @"owner"]) {
                            if ([row[key] isKindOfClass:NSString.class] && [row[key] length]) [required addObject:row[key]];
                        }
                        [required addObjectsFromArray:row[@"visibleCellClasses"] ?: @[]];
                    }
                    report[@"requestedClassNames"] = required.array;
                    report[@"metadataSelectionLimited"] = @(required.count > 96);
                    NSTimeInterval started = NSProcessInfo.processInfo.systemUptime;
                    NSArray *names = [required.array subarrayWithRange:NSMakeRange(0, MIN(required.count, 96UL))];
                    for (NSString *name in names) {
                        @autoreleasepool {
                            if (NSProcessInfo.processInfo.systemUptime - started > 20) { failure = @"time-budget-reached"; break; }
                            if (![archive saveStage:@"inspecting" className:name error:&error]) { failure = @"stage-write-failed"; break; }
                            // 不枚举全进程，不将Class当作ObjC对象放入字典，不展开Swift类型。
                            NSDictionary *metadata = [DYYYAssistantRuntimeInspector inspectClassNamed:name];
                            [interfaces addObject:metadata];
                            report[@"lastProcessedClass"] = name;
                            if (![archive saveReport:report error:&error]) { failure = @"checkpoint-write-failed"; break; }
                        }
                    }
                }
                if (saved && !failure) {
                    report[@"complete"] = @YES;
                    complete = [archive saveReport:report error:&error];
                    if (!complete) failure = @"final-write-failed";
                }
            } @catch (NSException *exception) {
                failure = [@"exception:" stringByAppendingString:exception.name ?: @"unknown"];
            } @finally {
                [archive saveStage:complete ? @"complete" : (failure ?: @"incomplete") className:@"" error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    recorder.exportInProgress = NO;
                    if (completion) completion();
                    [DYYYUtils showToast:complete ? @"诊断已保存，请点击“保存已有诊断到文件”" :
                        (saved ? @"生成未完成，已有快照可单独保存" : @"保存失败，请查看上次导出阶段")];
                });
            }
        }
    });
}
@end
