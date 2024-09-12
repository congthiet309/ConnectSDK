#import "AirPlayServiceMirrored.h"
#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVAsset.h>
#import "ConnectError.h"
#import "AirPlayWebAppSession.h"
#import "ConnectUtil.h"
#import "AirPlayService.h"

#import "NSObject+FeatureNotSupported_Private.h"

@interface AirPlayServiceWindow : UIWindow
@end

@implementation AirPlayServiceWindow

- (BOOL)isKeyWindow {
    return NO;
}

@end

@interface AirPlayServiceViewController : UIViewController
@end

@implementation AirPlayServiceViewController

- (BOOL)shouldAutorotate {
    return NO;
}
@end

@interface AirPlayServiceMirrored () <ServiceCommandDelegate, WKNavigationDelegate>

@property (nonatomic, copy) SuccessBlock launchSuccessBlock;
@property (nonatomic, copy) FailureBlock launchFailureBlock;

@property (nonatomic) AirPlayWebAppSession *activeWebAppSession;
@property (nonatomic) ServiceSubscription *playStateSubscription;
@property (nonatomic, strong) UIAlertController *connectingAlertController;

@end

@implementation AirPlayServiceMirrored
{
    NSTimer *_connectTimer;
}

- (instancetype)initWithAirPlayService:(AirPlayService *)service
{
    self = [super init];
    if (self) {
        _service = service;
    }
    return self;
}

- (void)connect
{
    [self checkForExistingScreenAndInitializeIfPresent];

    if (self.secondWindow && self.secondWindow.screen) {
        _connecting = NO;
        _connected = YES;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hScreenDisconnected:) name:UIScreenDidDisconnectNotification object:nil];

        if (self.service.connected && self.service.delegate && [self.service.delegate respondsToSelector:@selector(deviceServiceConnectionSuccess:)]) {
            dispatch_on_main(^{ [self.service.delegate deviceServiceConnectionSuccess:self.service]; });
        }
    } else {
        _connected = NO;
        _connecting = YES;

        [self checkScreenCount];

        NSString *title = [[NSBundle mainBundle] localizedStringForKey:@"Connect_SDK_AirPlay_Mirror_Title" value:@"Mirroring Required" table:@"ConnectSDK"];
        NSString *message = [[NSBundle mainBundle] localizedStringForKey:@"Connect_SDK_AirPlay_Mirror_Description" value:@"Enable AirPlay mirroring to connect to this device" table:@"ConnectSDK"];
        NSString *ok = [[NSBundle mainBundle] localizedStringForKey:@"Connect_SDK_AirPlay_Mirror_OK" value:@"OK" table:@"ConnectSDK"];
        NSString *cancel = [[NSBundle mainBundle] localizedStringForKey:@"Connect_SDK_AirPlay_Mirror_Cancel" value:@"Cancel" table:@"ConnectSDK"];

        __weak typeof(self) weakSelf = self;
        self.connectingAlertController = [UIAlertController alertControllerWithTitle:title
                                                                              message:message
                                                                       preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancel
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *action) {
            if (weakSelf.connecting) {
                [weakSelf disconnect];
            }
        }];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:ok
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
            // Additional actions on OK button can be placed here if needed
        }];

        [self.connectingAlertController addAction:cancelAction];
        [self.connectingAlertController addAction:okAction];

        // Present the UIAlertController
        UIViewController *rootVC = UIApplication.sharedApplication.keyWindow.rootViewController;
        [rootVC presentViewController:self.connectingAlertController animated:YES completion:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hScreenConnected:) name:UIScreenDidConnectNotification object:nil];

        if (self.service && self.service.delegate && [self.service.delegate respondsToSelector:@selector(deviceService:pairingRequiredOfType:withData:)]) {
            dispatch_on_main(^{ [self.service.delegate deviceService:self.service pairingRequiredOfType:DeviceServicePairingTypeAirPlayMirroring withData:self.connectingAlertController]; });
        }
    }
}

- (void)disconnect
{
    _connected = NO;
    _connecting = NO;

    [NSObject cancelPreviousPerformRequestsWithTarget:self];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenDidDisconnectNotification object:nil];

    if (self.secondWindow) {
        _secondWindow.hidden = YES;
        _secondWindow.screen = nil;
        _secondWindow = nil;
    }

    if (_connectTimer) {
        [_connectTimer invalidate];
        _connectTimer = nil;
    }

    if (self.connectingAlertController) {
        [self.connectingAlertController dismissViewControllerAnimated:NO completion:nil];
        self.connectingAlertController = nil;
    }

    if (self.service && self.service.delegate && [self.service.delegate respondsToSelector:@selector(deviceService:disconnectedWithError:)]) {
        [self.service.delegate deviceService:self.service disconnectedWithError:nil];
    }
}

- (int)sendSubscription:(ServiceSubscription *)subscription type:(ServiceSubscriptionType)type payload:(id)payload toURL:(NSURL *)URL withId:(int)callId
{
    if (type == ServiceSubscriptionTypeUnsubscribe) {
        if (subscription == self.playStateSubscription) {
            [[self.playStateSubscription successCalls] removeAllObjects];
            [[self.playStateSubscription failureCalls] removeAllObjects];
            [self.playStateSubscription setIsSubscribed:NO];
            self.playStateSubscription = nil;
        }
    }

    return -1;
}

#pragma mark - External display detection, setup

- (void)checkScreenCount
{
    if (_connectTimer) {
        [_connectTimer invalidate];
        _connectTimer = nil;
    }

    if (!self.connecting) return;

    if ([UIScreen screens].count > 1) {
        _connecting = NO;
        _connected = YES;

        if (self.connectingAlertController) {
            [self.connectingAlertController dismissViewControllerAnimated:NO completion:nil];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hScreenDisconnected:) name:UIScreenDidDisconnectNotification object:nil];

        if (self.service.connected && self.service.delegate && [self.service.delegate respondsToSelector:@selector(deviceServiceConnectionSuccess:)]) {
            dispatch_on_main(^{ [self.service.delegate deviceServiceConnectionSuccess:self.service]; });
        }
    } else {
        _connectTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkScreenCount) userInfo:nil repeats:NO];
    }
}

- (void)checkForExistingScreenAndInitializeIfPresent
{
    if ([[UIScreen screens] count] > 1) {
        UIScreen *secondScreen = [[UIScreen screens] objectAtIndex:1];

        CGRect screenBounds = secondScreen.bounds;

        _secondWindow = [[AirPlayServiceWindow alloc] initWithFrame:screenBounds];
        _secondWindow.screen = secondScreen;

        DLog(@"Displaying content with bounds %@", NSStringFromCGRect(screenBounds));
    }
}

- (void)hScreenConnected:(NSNotification *)notification
{
    DLog(@"%@", notification);

    if (!self.secondWindow) {
        [self checkForExistingScreenAndInitializeIfPresent];
    }

    [self checkScreenCount];
}

- (void)hScreenDisconnected:(NSNotification *)notification
{
    DLog(@"%@", notification);

    if (_connecting || _connected) {
        [self disconnect];
    }
}

#pragma mark - WebAppLauncher

// The rest of the code remains the same...

@end
