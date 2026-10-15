#import "DYYYAssistantViewController.h"
#import "DYYYAssistantPreferences.h"
#import "DYYYAssistantDiagnostics.h"
#import "DYYYConstants.h"
#import "DYYYCustomInputView.h"
#import "DYYYUtils.h"
#import "DYPlusCompatibilityViewController.h"

@interface DYYYAssistantViewController ()
@property(nonatomic, copy) NSString *mode;
@property(nonatomic, strong) DYYYAssistantPreferences *store;
@property(nonatomic, assign) BOOL exporting;
@end

@implementation DYYYAssistantViewController

#pragma mark - 页面入口

+ (void)presentFrom:(UIViewController *)controller {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!controller) return;
        UIViewController *presenter = controller;
        while (presenter.presentedViewController) presenter = presenter.presentedViewController;
        DYYYAssistantViewController *page = [[self alloc] initWithMode:@"home"];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:page];
        [presenter presentViewController:navigation animated:YES completion:nil];
    });
}

- (instancetype)initWithMode:(NSString *)mode {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _mode = [mode copy];
        _store = DYYYAssistantPreferences.sharedStore;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [self.mode isEqualToString:@"home"] ? DYYY_NAME : ([self.mode isEqualToString:@"streak"] ? @"自动续火花计划" : @"密友名单");
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 70;
    if ([self.mode isEqualToString:@"home"]) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - 设置布局

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self.mode isEqualToString:@"home"]) return section == 0 ? 2 : (section == 1 ? 6 : 1);
    if (section == 0) return [self.mode isEqualToString:@"streak"] ? 3 : 1;
    if (section == 1) return 2;
    return [self.store contactsForList:self.mode].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self.mode isEqualToString:@"home"]) return @[@"扩展功能（适配中）", @"40.3.0 接口诊断", @"原有兼容性设置"][section];
    return @[@"计划草稿", @"名单管理", @"已保存好友（左滑移除）"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ([self.mode isEqualToString:@"home"]) {
        if (section == 0) return @"本版可配置计划和名单；实际自动发送、火花检测与四处隐藏尚未接入。原有功能继续保留。";
        if (section == 1) return @"采集四个页面后生成诊断，再单独点击保存到文件。生成前先保存页面快照，并逐类保存检查点；若闪退，重开后可直接保存已有诊断和阶段记录，无需重新扫描。仅记录接口类型。";
        return @"关闭历史 Hook 需要通过 TrollFools 撤销注入。";
    }
    if (section == 0 && [self.mode isEqualToString:@"streak"]) return @"内容、手机当地时间和好友均可修改。发送接口待适配，当前不会发送消息；未来应用被 iOS 挂起时也不能保证定时执行。";
    if (section == 0) return @"接入后将统一隐藏指定好友在消息、粉丝、互关及内容分享中的条目；当前只保存名单，不会更改任何列表。";
    if (section == 1) return @"请使用稳定 UID / sec_uid（不是抖音号、昵称或主页链接），同一标识重复添加只更新备注。删除名单不会删除好友或聊天。";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Assistant"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Assistant"];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if ([self.mode isEqualToString:@"home"]) {
        if (indexPath.section == 0) {
            cell.textLabel.text = indexPath.row == 0 ? @"自动续火花" : @"密友";
            cell.detailTextLabel.text = @"名单与配置可用，实际功能待接入";
        } else if (indexPath.section == 1) {
            if (indexPath.row == 0) {
                cell.textLabel.text = DYYYAssistantDiagnostics.isCapturing ? @"停止页面采集" : @"开始页面采集（3分钟）";
                cell.detailTextLabel.text = DYYYAssistantDiagnostics.captureStatus;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = self.exporting ? @"正在生成诊断…" : @"停止并生成诊断（先保存）";
                cell.detailTextLabel.text = @"只检查指定接口，不扫描全进程或展开Swift类型";
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"保存已有诊断到文件";
                cell.detailTextLabel.text = @"直接打开文件保存器，不重新检查接口";
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"只生成页面快照（排障）";
                cell.detailTextLabel.text = @"不检查任何接口，用于单独验证保存路径";
            } else if (indexPath.row == 4) {
                cell.textLabel.text = @"复制上次导出阶段";
                cell.detailTextLabel.text = DYYYAssistantDiagnostics.exportStatus;
            } else {
                cell.textLabel.text = @"清空本次采集记录";
                cell.detailTextLabel.text = @"仅清除内存中的类型记录，不修改好友或设置";
            }
        } else cell.textLabel.text = @"兼容性与安全回退";
    } else if (indexPath.section == 0) {
        if ([self.mode isEqualToString:@"streak"]) {
            cell.textLabel.text = @[@"执行状态", @"消息内容", @"每日时间"][indexPath.row];
            cell.detailTextLabel.text = indexPath.row == 0 ? @"未启用：私信接口待适配" : (indexPath.row == 1 ? self.store.message : self.store.timeString);
        } else {
            cell.textLabel.text = @"四处统一隐藏指定好友";
            cell.detailTextLabel.text = @"未启用：消息 / 粉丝 / 互关 / 分享数据源待适配";
        }
        if (indexPath.row == 0) {
            UISwitch *toggle = UISwitch.new;
            toggle.on = NO;
            toggle.enabled = NO;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (indexPath.section == 1) {
        cell.textLabel.text = indexPath.row == 0 ? @"手动添加好友" : ([self.mode isEqualToString:@"streak"] ? @"一键添加有火花好友（待适配）" : @"从好友列表快捷添加（待适配）");
        if (indexPath.row == 1) {
            cell.detailTextLabel.text = @"先导出接口诊断，识别实际数据源";
            cell.textLabel.textColor = UIColor.secondaryLabelColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else {
        NSDictionary *contact = [self.store contactsForList:self.mode][indexPath.row];
        cell.textLabel.text = contact[@"nickname"];
        cell.detailTextLabel.text = contact[@"identifier"];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

#pragma mark - 用户操作

- (void)inputWithTitle:(NSString *)title value:(NSString *)value confirm:(void (^)(NSString *))confirm {
    DYYYCustomInputView *input = [[DYYYCustomInputView alloc] initWithTitle:title defaultText:value];
    input.onConfirm = confirm;
    [input show];
}

- (void)addContact {
    __weak typeof(self) weakSelf = self;
    [self inputWithTitle:@"好友 UID / sec_uid" value:@"" confirm:^(NSString *uid) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf inputWithTitle:@"好友备注（选填）" value:@"" confirm:^(NSString *name) {
                DYYYAssistantViewController *page = weakSelf;
                if (!page) return;
                BOOL saved = [page.store putIdentifier:uid nickname:name inList:page.mode];
                [DYYYUtils showToast:saved ? @"名单已保存，实际功能待接入" : @"标识或备注格式不正确"];
                [page.tableView reloadData];
            }];
        });
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    __weak typeof(self) weakSelf = self;
    if ([self.mode isEqualToString:@"home"]) {
        if (indexPath.section == 0) {
            [self.navigationController pushViewController:[[DYYYAssistantViewController alloc] initWithMode:indexPath.row == 0 ? @"streak" : @"privacy"] animated:YES];
        } else if (indexPath.section == 1 && !self.exporting) {
            if (indexPath.row == 0) {
                if (DYYYAssistantDiagnostics.isCapturing) {
                    [DYYYAssistantDiagnostics stopCapture];
                    [self.tableView reloadData];
                } else {
                    [DYYYAssistantDiagnostics startCapture];
                    [self dismissViewControllerAnimated:YES completion:^{
                        [DYYYUtils showToast:@"采集已开始，请关闭设置后浏览四个页面"];
                    }];
                }
            } else if (indexPath.row == 1) {
                self.exporting = YES;
                [self.tableView reloadData];
                [DYYYAssistantDiagnostics exportFromController:self completion:^{
                    weakSelf.exporting = NO;
                    [weakSelf.tableView reloadData];
                }];
            } else if (indexPath.row == 2) {
                [DYYYAssistantDiagnostics saveExistingFromController:self];
            } else if (indexPath.row == 3) {
                self.exporting = YES;
                [self.tableView reloadData];
                [DYYYAssistantDiagnostics saveSnapshotOnlyWithCompletion:^{
                    weakSelf.exporting = NO;
                    [weakSelf.tableView reloadData];
                }];
            } else if (indexPath.row == 4) {
                UIPasteboard.generalPasteboard.string = DYYYAssistantDiagnostics.exportStatus;
                [DYYYUtils showToast:@"导出阶段已复制"];
            } else {
                [DYYYAssistantDiagnostics clearCapture];
                [self.tableView reloadData];
            }
        } else if (indexPath.section == 2) {
            [self.navigationController pushViewController:[[DYPlusCompatibilityViewController alloc] init] animated:YES];
        }
    } else if (indexPath.section == 1 && indexPath.row == 0) [self addContact];
    else if (indexPath.section == 0 && [self.mode isEqualToString:@"streak"]) {
        if (indexPath.row == 1) {
            [self inputWithTitle:@"续火花内容（1～500字）" value:self.store.message confirm:^(NSString *text) {
                NSString *value = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (!value.length || value.length > 500) { [DYYYUtils showToast:@"请输入1～500字"]; return; }
                weakSelf.store.message = value;
                [weakSelf.tableView reloadData];
            }];
        } else if (indexPath.row == 2) {
            [self inputWithTitle:@"每日时间（24小时制 HH:mm）" value:self.store.timeString confirm:^(NSString *time) {
                if (![weakSelf.store setTimeString:time]) [DYYYUtils showToast:@"时间格式不正确，例如09:00"];
                [weakSelf.tableView reloadData];
            }];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return ![self.mode isEqualToString:@"home"] && indexPath.section == 2;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete || indexPath.section != 2) return;
    NSDictionary *contact = [self.store contactsForList:self.mode][indexPath.row];
    [self.store removeIdentifier:contact[@"identifier"] fromList:self.mode];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}
@end
