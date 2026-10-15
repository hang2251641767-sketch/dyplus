#import "DYYYAssistantDiagnosticArchive.h"

@interface DYYYAssistantDiagnosticArchive ()
@property(nonatomic, strong) NSURL *directory;
@end

@implementation DYYYAssistantDiagnosticArchive
- (instancetype)initWithDirectory:(NSURL *)directory {
    self = [super init];
    if (self) _directory = directory;
    return self;
}
- (NSURL *)reportURL { return [self.directory URLByAppendingPathComponent:@"DouyinAssistantPLUS-interfaces-v3.json"]; }
- (NSURL *)stateURL { return [self.directory URLByAppendingPathComponent:@"DouyinAssistantPLUS-export-state.json"]; }

- (BOOL)writeObject:(NSDictionary *)object toURL:(NSURL *)url error:(NSError **)error {
    @try {
        if (![NSFileManager.defaultManager createDirectoryAtURL:self.directory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:error];
        if (data.length > 8 * 1024 * 1024) {
            if (error) *error = [NSError errorWithDomain:@"DYYYAssistantDiagnosticArchive" code:2 userInfo:@{NSLocalizedDescriptionKey:@"诊断超过8MB，已保留上一检查点"}];
            return NO;
        }
        if (!data || ![data writeToURL:url options:NSDataWritingAtomic error:error]) return NO;
        [self.directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
        return YES;
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"DYYYAssistantDiagnosticArchive" code:1 userInfo:@{NSLocalizedDescriptionKey:exception.name ?: @"JSON write failed"}];
        return NO;
    }
}
- (BOOL)saveReport:(NSDictionary *)report error:(NSError **)error { return [self writeObject:report toURL:self.reportURL error:error]; }
- (BOOL)saveStage:(NSString *)stage className:(NSString *)className error:(NSError **)error {
    return [self writeObject:@{@"stage":stage ?: @"", @"class":className ?: @""} toURL:self.stateURL error:error];
}
- (NSDictionary *)lastStage {
    NSData *data = [NSData dataWithContentsOfURL:self.stateURL];
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [object isKindOfClass:NSDictionary.class] ? object : @{};
}
- (BOOL)hasReport { return [NSFileManager.defaultManager fileExistsAtPath:self.reportURL.path]; }
@end
