# TCNavigationController
A navigation bar integrated transition animation effect.

# Usage

## Initial

```objc
// AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    _window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    TCDashboardController *dashboard = [[TCDashboardController alloc] init];
    _window.rootViewController = [[TCNavigationController alloc] initWithRootViewController:dashboard];
    [_window makeKeyAndVisible];
    _window.backgroundColor = [UIColor blackColor];

    return YES;
}
```

## Push

```objc
// Some UIViewController
SFSafariViewControllerConfiguration *config = [[SFSafariViewControllerConfiguration alloc] init];
config.entersReaderIfAvailable = YES;
config.barCollapsingEnabled = NO;
SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:kTCMultiString(@"TCHelpArticleURL")] configuration:config];
safari.delegate = self;
[self.tcNavigationController pushViewController:safari];
```

## Present

```objc
// Some UIViewController
[self.tcNavigationController presentViewController:safari animated:YES completion:nil];
```
