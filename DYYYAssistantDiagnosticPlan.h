#import <Foundation/Foundation.h>

@interface DYYYAssistantDiagnosticPlan : NSObject
+ (NSArray<NSString *> *)targetClassNames;
+ (NSInteger)priorityForName:(NSString *)name;
+ (NSArray<NSString *> *)selectedNamesFromCandidates:(NSArray<NSDictionary *> *)candidates
                                     requiredNames:(NSArray<NSString *> *)requiredNames
                                supplementaryLimit:(NSUInteger)limit;
@end
