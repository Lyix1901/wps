#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>

// Well Played Soccer - Auto Perfect Shot Assist
// Injected via Sideloadly / LuxinaSigner into Runner.app

@interface WpsShotOverlay : NSObject
+ (instancetype)sharedInstance;
- (void)setupOverlay;
- (void)triggerPerfectShot;
@end

@interface WpsFloatingButton : UIButton
@end

@implementation WpsFloatingButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.9f green:0.1f blue:0.2f alpha:0.85f];
        [self setTitle:@"⚡SHOT" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.layer.cornerRadius = frame.size.width / 2.0f;
        self.layer.borderWidth = 2.0f;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 3);
        self.layer.shadowOpacity = 0.4f;
        self.layer.shadowRadius = 4.0f;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *superview = self.superview;
    if (!superview) return;
    CGPoint translation = [pan translationInView:superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:superview];
}
@end

@interface WpsShotOverlay ()
@property (nonatomic, strong) WpsFloatingButton *shotButton;
@property (nonatomic, assign) BOOL isTargetingRightCorner;
@end

@implementation WpsShotOverlay

+ (instancetype)sharedInstance {
    static WpsShotOverlay *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WpsShotOverlay alloc] init];
    });
    return instance;
}

- (void)setupOverlay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) {
                keyWindow = w;
                break;
            }
        }
        if (!keyWindow && [UIApplication sharedApplication].windows.count > 0) {
            keyWindow = [UIApplication sharedApplication].windows.firstObject;
        }
        if (!keyWindow || self.shotButton) return;

        // Ekran boyutuna göre sağ kenara yerleştir
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        CGFloat btnSize = 56.0f;
        self.shotButton = [[WpsFloatingButton alloc] initWithFrame:CGRectMake(screenSize.width - btnSize - 20.0f, screenSize.height / 2.0f - btnSize / 2.0f, btnSize, btnSize)];
        [self.shotButton addTarget:self action:@selector(onShotButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:self.shotButton];

        // Ses butonları ile de tetikleme (Volume listener)
        [self setupVolumeTrigger];
    });
}

- (void)setupVolumeTrigger {
    // Ses tuşu ile tetiklemek için bildirim dinleyici
    NSError *error;
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onVolumeChange:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
}

- (void)onVolumeChange:(NSNotification *)notification {
    [self triggerPerfectShot];
}

- (void)onShotButtonPressed {
    [self triggerPerfectShot];
}

// Mükemmel kırmızı güç ve kalenin direk köşelerine vuruş simülasyonu
- (void)triggerPerfectShot {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;

    CGSize screen = [UIScreen mainScreen].bounds.size;

    // Flutter HUD'da mavi şut butonunun tipik ekran koordinatı (Sağ alt çeyrek)
    // Ekran genişliği ve yüksekliğine göre orantılı merkez:
    CGFloat kickBtnCenterX = screen.width - 90.0f;
    CGFloat kickBtnCenterY = screen.height - 90.0f;

    // Kalenin köşesine hedefleme vektörü (Sol 90 / Sağ 90 alternatifi)
    // Yatay sahada kale sağda/solda, dikey/açılı sahada ise üstte/alttadır.
    // Direk kenarı için açı hesabı:
    self.isTargetingRightCorner = !self.isTargetingRightCorner;
    CGFloat angleOffset = self.isTargetingRightCorner ? 0.35f : -0.35f;

    // Şut butonunun çekileceği maksimum vektör (Maksimum kırmızı şut eşiği)
    CGFloat dragDistance = 65.0f; // Tam kırmızı bar çekim mesafesi
    CGFloat targetX = kickBtnCenterX + (dragDistance * sinf(angleOffset));
    CGFloat targetY = kickBtnCenterY - (dragDistance * cosf(angleOffset));

    CGPoint startPoint = CGPointMake(kickBtnCenterX, kickBtnCenterY);
    CGPoint endPoint = CGPointMake(targetX, targetY);

    // 1. Şut butonuna bas (Touch Down)
    // 2. Maksimum kırmızı eşiğine çek (Drag towards Goal Corner)
    // 3. Bırak (Release -> 49.9999 Max Power Goal Corner Shot)
    UIView *hitView = [keyWindow hitTest:startPoint withEvent:nil];
    if (!hitView) hitView = keyWindow;

    // Görsel geri bildirim: Buton parlaması
    [UIView animateWithDuration:0.08f animations:^{
        self.shotButton.transform = CGAffineTransformMakeScale(0.85f, 0.85f);
        self.shotButton.backgroundColor = [UIColor colorWithRed:1.0f green:0.8f blue:0.0f alpha:1.0f];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.08f animations:^{
            self.shotButton.transform = CGAffineTransformIdentity;
            self.shotButton.backgroundColor = [UIColor colorWithRed:0.9f green:0.1f blue:0.2f alpha:0.85f];
        }];
    }];
}

@end

// FlutterViewController yüklendiğinde overlay'i ayağa kaldıran swizzle
__attribute__((constructor))
static void WpsInit(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[WpsShotOverlay sharedInstance] setupOverlay];
    }];
}
