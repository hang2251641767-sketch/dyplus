#import <Foundation/Foundation.h>

@interface DYYYAssistantDiagnosticArchive : NSObject
- (instancetype)initWithDirectory:(NSURL *)directory;
@property(nonatomic, readonly, strong) NSURL *reportURL;
@property(nonatomic, readonly, strong) NSURL *stateURL;
- (BOOL)saveReport:(NSDictionary *)report error:(NSError **)error;
- (BOOL)saveStage:(NSString *)stage className:(NSString *)className error:(NSError **)error;
- (NSDictionary *)lastStage;
- (BOOL)hasReport;
@end
