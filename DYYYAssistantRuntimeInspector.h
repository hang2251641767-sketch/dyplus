#import <Foundation/Foundation.h>

@interface DYYYAssistantRuntimeInspector : NSObject
/// 仅用运行时C接口读取声明；不向被检查的Class发送ObjC消息或将其加入容器。
+ (NSDictionary *)inspectClassNamed:(NSString *)name;
@end
