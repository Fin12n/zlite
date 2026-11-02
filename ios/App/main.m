#import <UIKit/UIKit.h>
#import "CTDOBridge.h"
#import "CTDOMainViewController.h"

static CTDOMainViewController *createConfiguredMainViewController(void) {
    CTDOMainViewController *rootVC = [[CTDOMainViewController alloc] init];
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSString *initMode = env[@"CTDOZ_INITIAL_MODE"] ?: @"";
    if ([initMode isEqualToString:@"duo"]) {
        rootVC.preferredLayoutMode = CTDOLayoutModeiPhoneDuo;
        rootVC.duoDualChatMode = YES;
    } else if ([initMode isEqualToString:@"ipad"]) {
        rootVC.preferredLayoutMode = CTDOLayoutModeiPadThreeColumn;
    } else if ([initMode isEqualToString:@"compact"]) {
        rootVC.preferredLayoutMode = CTDOLayoutModeCompactPhone;
    }
    return rootVC;
}

// ============================================================================
// iOS 13.0 - iOS 27.0+ UISceneDelegate (Supports iPad Split-View & iPhone Duo Multi-Scene)
// Ignored on iOS 12.0 where AppDelegate.window is used directly.
// ============================================================================
API_AVAILABLE(ios(13.0))
@interface CTDOSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation CTDOSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions API_AVAILABLE(ios(13.0)) {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.rootViewController = createConfiguredMainViewController();
    [self.window makeKeyAndVisible];
}

@end

// ============================================================================
// iOS 12.0+ UIApplicationDelegate (Direct UIWindow on iOS 12, UIScene on iOS 13+)
// ============================================================================
@interface CTDOAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic, nullable) UIWindow *secondaryDuoWindow;
@end

@implementation CTDOAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (@available(iOS 13.0, *)) {
        // On iOS 13+, CTDOSceneDelegate initializes the primary windowScene.
    } else {
        // On iOS 12.0 - 12.5.x, initialize UIWindow directly on UIScreen.mainScreen.
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        self.window.rootViewController = createConfiguredMainViewController();
        [self.window makeKeyAndVisible];
    }

    // Observe secondary integrated/external screen for iPhone Duo (primary-1 / LCD-1) on iOS 12
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onScreenDidConnect:)
                                                 name:UIScreenDidConnectNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onScreenDidDisconnect:)
                                                 name:UIScreenDidDisconnectNotification
                                               object:nil];
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                              options:(UISceneConnectionOptions *)options API_AVAILABLE(ios(13.0)) {
    UISceneConfiguration *cfg = [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                                               sessionRole:connectingSceneSession.role];
    cfg.delegateClass = [CTDOSceneDelegate class];
    return cfg;
}

- (void)onScreenDidConnect:(NSNotification *)note {
    if (@available(iOS 13.0, *)) {
        return;
    }
    UIScreen *newScreen = note.object;
    if ([newScreen isKindOfClass:[UIScreen class]] && newScreen != [UIScreen mainScreen]) {
        self.secondaryDuoWindow = [[UIWindow alloc] initWithFrame:newScreen.bounds];
        self.secondaryDuoWindow.screen = newScreen;
        CTDOMainViewController *duoVC = [[CTDOMainViewController alloc] init];
        duoVC.preferredLayoutMode = CTDOLayoutModeiPhoneDuo;
        duoVC.duoDualChatMode = YES;
        self.secondaryDuoWindow.rootViewController = duoVC;
        self.secondaryDuoWindow.hidden = NO;
    }
}

- (void)onScreenDidDisconnect:(NSNotification *)note {
    self.secondaryDuoWindow.hidden = YES;
    self.secondaryDuoWindow = nil;
}

@end

static int runHeadlessSelfTest(void) {
    @autoreleasepool {
        CTDOCoreBridge *core = [CTDOCoreBridge shared];
        NSString *ver = [core versionString];
        if (![ver isEqualToString:@"0.0.5"]) {
            fprintf(stderr, "[FAIL] Expected version 0.0.5, got %s\n", [ver UTF8String]);
            return 1;
        }
        NSArray<NSDictionary *> *threads = [core listThreadsForSlot:0 filterMode:0 searchQuery:@""];
        if (threads.count < 4) {
            fprintf(stderr, "[FAIL] Expected >= 4 seeded threads, got %lu\n", (unsigned long)threads.count);
            return 2;
        }
        // Verify #63 duplicate display name isolation ("Nguyễn Văn An")
        NSMutableArray *anIds = [NSMutableArray array];
        for (NSDictionary *t in threads) {
            if ([t[@"name"] isEqualToString:@"Nguyễn Văn An"]) {
                [anIds addObject:t[@"id"]];
            }
        }
        if (anIds.count < 2 || [anIds[0] isEqualToString:anIds[1]]) {
            fprintf(stderr, "[FAIL] Issue #63 duplicate display name threads merged or missing!\n");
            return 3;
        }
        // Verify ParamCipher v2 & signkey
        NSDictionary *signedReq = [core buildSignedRequestForService:@"chat"
                                                              method:@"sendmsg"
                                                          jsonParams:@"{\"msg\":\"hello ios 12\"}"];
        if ([signedReq[@"signkey"] length] != 32) {
            fprintf(stderr, "[FAIL] Invalid MD5 signkey length\n");
            return 4;
        }
        // Verify iPhone Duo geometry detection (951x669 and 466x678)
        if (![core isiPhoneDuoHardwareOrGeometry:CGSizeMake(951, 669)] ||
            ![core isiPhoneDuoHardwareOrGeometry:CGSizeMake(466, 678)]) {
            fprintf(stderr, "[FAIL] iPhone Duo geometry detector failed\n");
            return 5;
        }
        printf("[PASS] ctdozlite iOS v%s self-test OK (min iOS 12.0+, #63, #38, #35, #27, iPhone Duo verified)\n",
               [ver UTF8String]);
        return 0;
    }
}

int main(int argc, char * argv[]) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--self-test") == 0) {
            return runHeadlessSelfTest();
        }
    }
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CTDOAppDelegate class]));
    }
}
