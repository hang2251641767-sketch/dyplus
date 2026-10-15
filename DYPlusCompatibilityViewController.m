#import "DYPlusCompatibilityViewController.h"
#import "DYPlusFeatureRegistry.h"

@implementation DYPlusCompatibilityViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"抖音助手PLUS兼容性";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    // Subtitle 样式用于显示模块说明；不要用 registerClass 覆盖 cell style。
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 1 ? DYPlusFeatureRegistry.modules.count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"运行状态" : (section == 1 ? @"模块开关" : @"故障回退");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"目标版本为抖音 40.3.0。版本匹配只代表版本号相同，不代表 Hook 已在真机验证。";
    if (section == 1) return @"所有新模块默认关闭。总开关关闭或版本不匹配时，模块将以 fail-closed 方式不执行。";
    return @"回退仅关闭 DYPlus 新模块；上游 DYYY 历史 Hook 的兼容性仍需单独进行真机测试。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DYPlusCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DYPlusCell"];
    }
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (indexPath.section == 0) {
        cell.textLabel.text = [DYPlusFeatureRegistry isTargetAppVersion] ? @"版本号：40.3.0（匹配）" : @"版本号：非 40.3.0（已阻断新模块）";
        UISwitch *toggle = UISwitch.new;
        toggle.on = DYPlusFeatureRegistry.isMasterEnabled;
        toggle.enabled = [DYPlusFeatureRegistry isTargetAppVersion];
        [toggle addTarget:self action:@selector(masterChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else if (indexPath.section == 1) {
        NSDictionary *module = DYPlusFeatureRegistry.modules[indexPath.row];
        cell.textLabel.text = module[@"title"];
        cell.detailTextLabel.text = module[@"detail"];
        UISwitch *toggle = UISwitch.new;
        toggle.on = [NSUserDefaults.standardUserDefaults boolForKey:module[@"id"]];
        toggle.accessibilityIdentifier = module[@"id"];
        [toggle addTarget:self action:@selector(moduleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else {
        cell.textLabel.text = @"恢复安全默认值";
        cell.textLabel.textColor = UIColor.systemRedColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)masterChanged:(UISwitch *)sender {
    if (![DYPlusFeatureRegistry isTargetAppVersion]) {
        sender.on = NO;
        return;
    }
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:@"DYPlusMasterEnabled"];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)moduleChanged:(UISwitch *)sender {
    [DYPlusFeatureRegistry setFeature:sender.accessibilityIdentifier enabled:sender.on];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 2) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"恢复安全默认值" message:@"将关闭 DYPlus 总开关和全部新模块。重启抖音后生效。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"立即恢复" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [DYPlusFeatureRegistry restoreSafeDefaults];
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
