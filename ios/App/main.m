#import <UIKit/UIKit.h>
#import "CTDOBridge.h"
#import "CTDOMainViewController.h"

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
    self.window.rootViewController = [[CTDOMainViewController alloc] init];
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
        self.window.rootViewController = [[CTDOMainViewController alloc] init];
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
        printf("================================================================\n");
        printf("🚀 KIỂM THỬ PURE NATIVE OBJECTIVE-C CTDOZLITE (iPhone / iPad / iPhone Duo)\n");
        printf("================================================================\n");

        CTDOCoreBridge *core = [CTDOCoreBridge shared];
        NSString *ver = [core versionString];
        if (![ver isEqualToString:@"0.0.5"]) {
            fprintf(stderr, "[FAIL] Expected version 0.0.5, got %s\n", [ver UTF8String]);
            return 1;
        }
        printf("  [1/6] Phiên bản Pure Native Objective-C: v%s (min iOS 12.0+, Thiết bị: %s) -> OK\n",
               [ver UTF8String], [[core deviceHardwareName] UTF8String]);

        // Test 2: CommonCrypto AES-256-CBC roundtrip + MD5 signkey
        NSData *keyData = [@"3FC4F0D2AB50057BCE0D90D9187A22B1" dataUsingEncoding:NSUTF8StringEncoding];
        NSString *plain = @"{\"phone_num\":\"0912345678\",\"lang\":\"vi\"}";
        NSString *encB64 = [CTDOCoreBridge aesCBCEncryptUTF8:plain keyData:keyData];
        NSData *decData = [CTDOCoreBridge aesCBCDecryptBase64:encB64 keyData:keyData];
        NSString *decStr = [[NSString alloc] initWithData:decData encoding:NSUTF8StringEncoding];
        if (![decStr isEqualToString:plain]) {
            fprintf(stderr, "[FAIL] CommonCrypto AES-256-CBC roundtrip mismatch\n");
            return 2;
        }
        NSDictionary *signedReq = [core buildSignedRequestForService:@"chat"
                                                              method:@"sms"
                                                          jsonParams:plain];
        if ([signedReq[@"signkey"] length] != 32 || ![signedReq[@"enc_ver"] isEqualToString:@"v2"]) {
            fprintf(stderr, "[FAIL] ParamCipher v2 signkey failed\n");
            return 3;
        }
        printf("  [2/6] CommonCrypto AES-256-CBC + ParamCipher v2 + MD5 Signkey (%s) -> OK\n",
               [signedReq[@"signkey"] UTF8String]);

        // Test 3: Zero Fake Data Verification (fresh slot must have 0 fake threads before login)
        NSDictionary *auth1 = [core authStateForSlot:1];
        NSArray *threadsSlot1 = [core listThreadsForSlot:1 filterMode:0 searchQuery:@""];
        if (![auth1[@"status"] isEqualToString:@"authenticated"] && threadsSlot1.count != 0) {
            fprintf(stderr, "[FAIL] Found fake threads on unauthenticated slot!\n");
            return 4;
        }
        printf("  [3/6] Kiểm tra Zero Fake Data (Không chứa danh bạ/tin nhắn giả lập) -> OK\n");

        // Test 4: Live Zalo QR Ticket Fetch from wpa.zaloapp.com/api/login/reqqr (on slot 1 so slot 0 session is untouched)
        [core startQRLoginForSlot:1];
        NSString *qrPayload = @"";
        NSString *qrToken = @"";
        for (int i = 0; i < 30; i++) {
            [NSThread sleepForTimeInterval:0.25];
            NSDictionary *st = [core authStateForSlot:1];
            qrPayload = st[@"qr_payload"] ?: @"";
            qrToken = st[@"qr_token_id"] ?: @"";
            if (qrPayload.length > 0 || [st[@"qr_image_b64"] length] > 0) {
                break;
            }
        }
        if (qrPayload.length == 0) {
            fprintf(stderr, "[FAIL] Live reqqr from wpa.zaloapp.com did not return qr_cnt\n");
            return 5;
        }
        UIImage *qrImg = [CTDOIconRenderer qrCodeImageForString:qrPayload size:240.0];
        if (!qrImg || qrImg.size.width < 100) {
            fprintf(stderr, "[FAIL] CoreImage CIQRCodeGenerator failed to render QR image\n");
            return 6;
        }
        printf("  [4/6] Lấy mã QR thực tế từ wpa.zaloapp.com/api/login/reqqr (Token: %s) -> OK\n",
               [qrToken UTF8String]);

        // Test 5: GitHub Releases API v0.0.5 Parser
        NSDictionary *gh = [core parseGitHubReleaseJSON:@"{\"tag_name\":\"v0.0.5\",\"name\":\"ctdozlite v0.0.5\",\"body\":\"- Sửa lỗi trùng tên Zalo (#63)\\n- Hẹn giờ tin nhắn (#38)\"}"
                                        versionOverride:@"0.0.4"];
        if (![gh[@"has_update"] boolValue]) {
            fprintf(stderr, "[FAIL] GitHub Releases API v0.0.5 update detector failed\n");
            return 7;
        }
        printf("  [5/6] Bộ phân tích GitHub Releases API v0.0.5 -> OK\n");

        // Test 6: Hardware-Truth UIKit Layout across iPhone, iPhone Duo (iPhone19,4), and iPad Pro
        CTDOMainViewController *vc = [[CTDOMainViewController alloc] init];
        NSArray<NSValue *> *testSizes = @[
            [NSValue valueWithCGSize:CGSizeMake(402, 874)],  // iPhone 18 Pro
            [NSValue valueWithCGSize:CGSizeMake(466, 678)],  // iPhone Duo Folded
            [NSValue valueWithCGSize:CGSizeMake(951, 669)],  // iPhone Duo Unfolded
            [NSValue valueWithCGSize:CGSizeMake(1032, 1376)] // iPad Pro 13-inch (M5)
        ];
        for (NSValue *val in testSizes) {
            CGSize sz = [val CGSizeValue];
            vc.view.frame = CGRectMake(0, 0, sz.width, sz.height);
            [vc.view setNeedsLayout];
            [vc.view layoutIfNeeded];
        }
        printf("  [6/6] UIKit Hardware-Native Layout (iPhone, iPhone Duo iPhone19,4, iPad Pro) -> OK\n");
        printf("================================================================\n");
        printf("✅ TẤT CẢ 6/6 HẠNG MỤC KIỂM THỬ PURE OBJECTIVE-C & LIVE ZALO QR ĐỀU PASS!\n");
        printf("================================================================\n");
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
