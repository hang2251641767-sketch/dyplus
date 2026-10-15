#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "DYYYAssistantRuntimeInspector.h"
#import "DYYYAssistantDiagnosticArchive.h"

static BOOL DYYYProbeInitialized = NO;
@interface DYYYDiagnosticSafetyProbe : NSObject
@property(nonatomic, copy) NSString *sampleValue;
- (void)sampleMethod;
@end
@implementation DYYYDiagnosticSafetyProbe
+ (void)initialize { DYYYProbeInitialized = YES; }
- (void)sampleMethod {}
@end

int main(void) {
    @autoreleasepool {
        NSDictionary *metadata = [DYYYAssistantRuntimeInspector inspectClassNamed:@"DYYYDiagnosticSafetyProbe"];
        NSCAssert([metadata[@"foundAtExport"] boolValue], @"应读取到已注册类");
        NSCAssert(!DYYYProbeInitialized, @"检查接口不得触发目标类initialize");
        NSArray *selectors = [metadata[@"instanceMethods"] valueForKey:@"selector"];
        NSCAssert([selectors containsObject:@"sampleMethod"], @"应导出目标方法");
        NSCAssert([NSJSONSerialization isValidJSONObject:metadata], @"元数据必须可序列化");
        NSCAssert(![[DYYYAssistantRuntimeInspector inspectClassNamed:@"DYYYMissingClassForTest"][@"foundAtExport"] boolValue], @"缺失类不得当作可用");
        NSCAssert([DYYYAssistantRuntimeInspector inspectClassNamed:@"_TtCTestSwift"][@"skipped"] != nil, @"安全模式不展开Swift类型");
        // 对比旧实现的Class值入容器操作，仅在测试夹具上验证，不检查抖音类。
        Class probe = objc_lookUpClass("DYYYDiagnosticSafetyProbe");
        NSMutableDictionary *legacy = [NSMutableDictionary dictionary];
        legacy[@"class"] = probe;
        NSLog(@"legacyClassContainerInitialized=%@", DYYYProbeInitialized ? @"YES" : @"NO");

        NSURL *root = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        NSURL *directory = [root URLByAppendingPathComponent:[@"dyplus-safety-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
        DYYYAssistantDiagnosticArchive *archive = [[DYYYAssistantDiagnosticArchive alloc] initWithDirectory:directory];
        NSError *error = nil;
        NSDictionary *snapshot = @{@"schema":@3, @"complete":@NO, @"capturedListViewTypes":@[]};
        NSCAssert([archive saveReport:snapshot error:&error], @"快照应先成功保存");
        NSData *before = [NSData dataWithContentsOfURL:archive.reportURL];
        NSCAssert([archive saveStage:@"inspecting" className:@"TestClass" error:&error], @"应记录活动阶段");
        DYYYAssistantDiagnosticArchive *reopened = [[DYYYAssistantDiagnosticArchive alloc] initWithDirectory:directory];
        NSCAssert(reopened.hasReport && [reopened.lastStage[@"class"] isEqual:@"TestClass"], @"重开后应能取出快照和阶段");
        NSCAssert(![archive saveReport:@{@"bad":[NSObject new]} error:&error], @"非JSON对象应报错而非终止进程");
        NSCAssert([before isEqualToData:[NSData dataWithContentsOfURL:archive.reportURL]], @"失败不能破坏检查点");
        NSString *large = [@"x" stringByPaddingToLength:8 * 1024 * 1024 withString:@"x" startingAtIndex:0];
        NSCAssert(![archive saveReport:@{@"large":large} error:&error], @"过大报告应停止扩展");
        NSCAssert([before isEqualToData:[NSData dataWithContentsOfURL:archive.reportURL]], @"体积限制不能清空旧快照");
        [@"invalid-json" writeToURL:archive.stateURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSCAssert(archive.lastStage.count == 0, @"损坏阶段文件应安全回退");
        NSCAssert([directory.path hasPrefix:root.path], @"测试清理范围必须位于临时目录");
        [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
        NSLog(@"诊断检查点与运行时安全测试通过");
    }
    return 0;
}
