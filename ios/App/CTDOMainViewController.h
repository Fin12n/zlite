#import <UIKit/UIKit.h>
#import "CTDOBridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface CTDOMainViewController : UIViewController
@property (nonatomic, assign) BOOL duoDualChatMode; // On iPhone Duo hardware: toggle between Master-Detail (List + Chat) and Dual-Chat (Chat #1 + Chat #2)
- (void)refreshAllData;
- (void)triggerGitHubUpdateCheck:(BOOL)simulateOldVersion;
@end

NS_ASSUME_NONNULL_END
