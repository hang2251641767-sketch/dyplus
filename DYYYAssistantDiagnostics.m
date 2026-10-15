#import "DYYYAssistantDiagnostics.h"
#import "DYYYConstants.h"
#import "DYYYUtils.h"
#import <objc/runtime.h>

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
    // 限制单类体积；只记录签名，不执行任何私有方法。
    for (unsigned int i = 0; i < MIN(count, 200U); i++) {
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
    for (unsigned int i = 0; i < MIN(count, 200U); i++) {
        const char *attributes = property_getAttributes(items[i]);
        [properties addObject:@{@"name":@(property_getName(items[i])), @"attributes":attributes ? @(attributes) : @""}];
    }
    free(items);
    NSMutableArray *ivars = [NSMutableArray array];
    Ivar *fields = class_copyIvarList(cls, &count);
    for (unsigned int i = 0; i < MIN(count, 200U); i++) {
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

+ (NSArray *)viewTypes {
    NSAssert(NSThread.isMainThread, @"视图检查必须在主线程");
    NSMutableArray<UIView *> *queue = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) [queue addObjectsFromArray:((UIWindowScene *)scene).windows];
    }
    NSMutableArray *rows = [NSMutableArray array];
    NSUInteger visited = 0;
    while (queue.count && visited++ < 4000) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (queue.count < 4000) [queue addObjectsFromArray:view.subviews];
        if ([view isKindOfClass:UITableView.class]) {
            UITableView *table = (UITableView *)view;
            [rows addObject:@{@"view":NSStringFromClass(view.class), @"kind":@"table",
                              @"dataSource":table.dataSource ? NSStringFromClass([table.dataSource class]) : @"",
                              @"delegate":table.delegate ? NSStringFromClass([table.delegate class]) : @""}];
        } else if ([view isKindOfClass:UICollectionView.class]) {
            UICollectionView *collection = (UICollectionView *)view;
            [rows addObject:@{@"view":NSStringFromClass(view.class), @"kind":@"collection",
                              @"dataSource":collection.dataSource ? NSStringFromClass([collection.dataSource class]) : @"",
                              @"delegate":collection.delegate ? NSStringFromClass([collection.delegate class]) : @""}];
        }
    }
    return rows;
}

#pragma mark - 手动导出

+ (void)exportFromController:(UIViewController *)controller completion:(void (^)(void))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self exportFromController:controller completion:completion]; });
        return;
    }
    NSArray *views = [self viewTypes];
    NSDictionary *version = @{@"appVersion":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"未知",
                              @"appBuild":[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"未知",
                              @"systemVersion":UIDevice.currentDevice.systemVersion, @"pluginVersion":DYYY_VERSION};
    __weak UIViewController *weakController = controller;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableArray *classes = [NSMutableArray array];
        NSMutableSet *included = [NSMutableSet set];
        unsigned int count = 0;
        Class *loaded = objc_copyClassList(&count);
        NSUInteger matched = 0;
        for (unsigned int i = 0; i < count; i++) {
            NSString *name = NSStringFromClass(loaded[i]);
            const char *image = class_getImageName(loaded[i]);
            NSString *imagePath = image ? @(image) : @"";
            if (![imagePath hasPrefix:NSBundle.mainBundle.bundlePath] || ![self isRelevantName:name]) continue;
            matched++;
            if (classes.count >= 1800) continue;
            [classes addObject:[self metadataForClass:loaded[i]]];
            [included addObject:name];
        }
        // 补充 UIKit 快照中数据源的确切类型，避免仅按命名筛选漏掉列表代理。
        for (NSDictionary *row in views) {
            for (NSString *key in @[@"dataSource", @"delegate"]) {
                NSString *name = row[key];
                Class cls = NSClassFromString(name);
                if (!cls || [included containsObject:name]) continue;
                [classes addObject:[self metadataForClass:cls]];
                [included addObject:name];
            }
        }
        free(loaded);
        NSDictionary *report = @{@"schema":@1, @"metadataOnly":@YES, @"version":version,
                                 @"matchingClassCount":@(matched), @"truncated":@(matched > 1800),
                                 @"listViewTypes":views, @"interfaces":classes};
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&error];
        NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"DouyinAssistantPLUS-interfaces.json"]];
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
