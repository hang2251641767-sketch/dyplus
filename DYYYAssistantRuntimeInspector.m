#import "DYYYAssistantRuntimeInspector.h"
#import <objc/runtime.h>

@implementation DYYYAssistantRuntimeInspector

+ (NSString *)text:(const char *)value {
    return value ? ([NSString stringWithUTF8String:value] ?: @"<invalid UTF-8>") : @"";
}

+ (NSDictionary *)methodsForClass:(Class)cls {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableArray *rows = [NSMutableArray array];
    @try {
        for (unsigned int i = 0; methods && i < MIN(count, 1024U); i++) {
            [rows addObject:@{@"selector":[self text:sel_getName(method_getName(methods[i]))],
                              @"encoding":[self text:method_getTypeEncoding(methods[i])]}];
        }
    } @finally { free(methods); }
    return @{@"items":rows, @"total":@(count), @"limited":@(count > rows.count)};
}

+ (NSDictionary *)inspectClassNamed:(NSString *)name {
    @autoreleasepool {
        if (!name.length) return @{@"class":@"", @"foundAtExport":@NO};
        // Swift名称保留为线索，不在本次修复版展开其运行时元数据。
        if ([name hasPrefix:@"_Tt"] || [name containsString:@"."]) {
            return @{@"class":name, @"skipped":@"Swift metadata omitted in safe mode"};
        }
        Class cls = objc_lookUpClass(name.UTF8String);
        if (!cls) return @{@"class":name, @"foundAtExport":@NO};
        @try {
            NSDictionary *instanceMethods = [self methodsForClass:cls];
            NSDictionary *classMethods = [self methodsForClass:object_getClass(cls)];
            NSMutableArray *properties = [NSMutableArray array];
            NSMutableArray *ivars = [NSMutableArray array];
            unsigned int propertyCount = 0, ivarCount = 0;
            objc_property_t *items = class_copyPropertyList(cls, &propertyCount);
            @try {
                for (unsigned int i = 0; items && i < MIN(propertyCount, 512U); i++) {
                    [properties addObject:@{@"name":[self text:property_getName(items[i])],
                                            @"attributes":[self text:property_getAttributes(items[i])]}];
                }
            } @finally { free(items); }
            Ivar *fields = class_copyIvarList(cls, &ivarCount);
            @try {
                for (unsigned int i = 0; fields && i < MIN(ivarCount, 512U); i++) {
                    [ivars addObject:@{@"name":[self text:ivar_getName(fields[i])],
                                      @"encoding":[self text:ivar_getTypeEncoding(fields[i])]}];
                }
            } @finally { free(fields); }
            return @{@"class":name, @"foundAtExport":@YES,
                     @"superclass":class_getSuperclass(cls) ? [self text:class_getName(class_getSuperclass(cls))] : @"",
                     @"instanceMethods":instanceMethods[@"items"], @"classMethods":classMethods[@"items"],
                     @"properties":properties, @"ivars":ivars,
                     @"instanceMethodCount":instanceMethods[@"total"], @"classMethodCount":classMethods[@"total"],
                     @"propertyCount":@(propertyCount), @"ivarCount":@(ivarCount),
                     @"metadataLimited":@([instanceMethods[@"limited"] boolValue] || [classMethods[@"limited"] boolValue] || propertyCount > properties.count || ivarCount > ivars.count)};
        } @catch (NSException *exception) {
            return @{@"class":name, @"foundAtExport":@YES, @"inspectionError":exception.name ?: @"UnknownException"};
        }
    }
}
@end
