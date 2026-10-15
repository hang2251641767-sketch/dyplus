#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 只读取已加载类的接口元数据和可见视图类型，不读取联系人/聊天/凭证。
@interface DYYYAssistantDiagnostics : NSObject
+ (void)startCapture;
+ (void)stopCapture;
+ (void)clearCapture;
+ (BOOL)isCapturing;
+ (NSString *)captureStatus;
+ (NSString *)exportStatus;
+ (void)saveExistingFromController:(UIViewController *)controller;
+ (void)saveSnapshotOnlyWithCompletion:(void (^)(void))completion;
+ (void)exportFromController:(UIViewController *)controller completion:(void (^)(void))completion;
@end

NS_ASSUME_NONNULL_END
