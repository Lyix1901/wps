#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

// ==========================================
// Mock UITouch for 100% Native Flutter Touch Delivery
// ==========================================
@interface WpsMockTouch : UITouch
@property (nonatomic, assign) CGPoint customLocation;
@property (nonatomic, assign) CGPoint customPreviousLocation;
@property (nonatomic, assign) UITouchPhase customPhase;
@property (nonatomic, assign) NSTimeInterval customTimestamp;
@property (nonatomic, weak) UIView *customView;
@property (nonatomic, weak) UIWindow *customWindow;
@end

@implementation WpsMockTouch
- (CGPoint)locationInView:(UIView *)view {
    return self.customLocation;
}
- (CGPoint)previousLocationInView:(UIView *)view {
    return self.customPreviousLocation;
}
- (UITouchPhase)phase {
    return self.customPhase;
}
- (NSTimeInterval)timestamp {
    return self.customTimestamp;
}
- (UIWindow *)window {
    return self.customWindow;
}
- (UIView *)view {
    return self.customView;
}
- (NSUInteger)tapCount {
    return 1;
}
@end

// ==========================================
// Status Toast Overlay (Only for Calibration Banner)
// ==========================================
@interface WpsStatusOverlay : UIView
@property (nonatomic, copy) NSString *message;
@end

@implementation WpsStatusOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    if (self.message.length == 0) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGSize scr = self.bounds.size;
    CGRect bannerRect = CGRectMake(scr.width / 2.0f - 180.0f, 10.0f, 360.0f, 26.0f);
    CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 0.75);
    CGContextFillRect(ctx, bannerRect);

    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:12.0f],
        NSForegroundColorAttributeName: [UIColor colorWithRed:1.0f green:0.85f blue:0.1f alpha:1.0f]
    };
    [self.message drawInRect:CGRectMake(bannerRect.origin.x + 10, bannerRect.origin.y + 5, bannerRect.size.width - 20, 18) withAttributes:attrs];
}
@end

// ==========================================
// Tweak Manager
// ==========================================
@interface WpsShotManager : NSObject
+ (instancetype)sharedInstance;
- (void)setupTweak;
- (void)onKickButtonTouchedAt:(CGPoint)pos;
- (void)triggerPerfectCornerShot;
@end

@implementation WpsShotManager {
    UIButton *_shotBtn;
    WpsStatusOverlay *_statusOverlay;
    BOOL _targetingRightCorner;
    CGPoint _calibratedKickPos;
    BOOL _isCalibrated;
}

+ (instancetype)sharedInstance {
    static WpsShotManager *inst = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        inst = [[WpsShotManager alloc] init];
    });
    return inst;
}

- (UIViewController *)findFlutterVC:(UIViewController *)vc {
    if (!vc) return nil;
    if ([NSStringFromClass([vc class]) containsString:@"FlutterViewController"]) {
        return vc;
    }
    for (UIViewController *child in vc.childViewControllers) {
        UIViewController *res = [self findFlutterVC:child];
        if (res) return res;
    }
    if (vc.presentedViewController) {
        UIViewController *res = [self findFlutterVC:vc.presentedViewController];
        if (res) return res;
    }
    return nil;
}

- (void)setupTweak {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWin = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWin = w; break; }
        }
        if (!keyWin && [UIApplication sharedApplication].windows.count > 0) {
            keyWin = [UIApplication sharedApplication].windows.firstObject;
        }
        if (!keyWin) return;

        CGSize scr = [UIScreen mainScreen].bounds.size;
        CGFloat w = MAX(scr.width, scr.height);
        CGFloat h = MIN(scr.width, scr.height);

        // Ekran görüntüsünden teyit edilen gerçek koordinat: (761, 212)
        self->_calibratedKickPos = CGPointMake(761.0f, 212.0f);
        self->_isCalibrated = YES;

        // Bilgilendirme Banner Katmanı
        if (!self->_statusOverlay) {
            self->_statusOverlay = [[WpsStatusOverlay alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            self->_statusOverlay.message = @"[WPS] ⚡SHOT Butonu Hazır! (761, 212)";
            [keyWin addSubview:self->_statusOverlay];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self->_statusOverlay.message = @"";
                [self->_statusOverlay setNeedsDisplay];
            });
        }

        // ⚡SHOT Butonu (Kırmızı Daire)
        if (!self->_shotBtn) {
            self->_shotBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            self->_shotBtn.frame = CGRectMake(w - 75.0f, h / 2.0f - 35.0f, 65.0f, 65.0f);
            self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.25f alpha:0.92f];
            [self->_shotBtn setTitle:@"⚡SHOT" forState:UIControlStateNormal];
            self->_shotBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.0f];
            [self->_shotBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self->_shotBtn.layer.cornerRadius = 32.5f;
            self->_shotBtn.layer.borderWidth = 2.5f;
            self->_shotBtn.layer.borderColor = [UIColor whiteColor].CGColor;
            self->_shotBtn.layer.shadowColor = [UIColor blackColor].CGColor;
            self->_shotBtn.layer.shadowOffset = CGSizeMake(0, 3);
            self->_shotBtn.layer.shadowOpacity = 0.5f;
            self->_shotBtn.layer.shadowRadius = 4.0f;

            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
            [self->_shotBtn addGestureRecognizer:pan];
            [self->_shotBtn addTarget:self action:@selector(triggerPerfectCornerShot) forControlEvents:UIControlEventTouchUpInside];
            [keyWin addSubview:self->_shotBtn];
        }

        // Fiziksel Ses Açma Tuşu Hook
        [self setupVolumeHook];
    });
}

- (void)onKickButtonTouchedAt:(CGPoint)pos {
    _calibratedKickPos = pos;
    _isCalibrated = YES;
    _statusOverlay.message = [NSString stringWithFormat:@"🎯 ŞUT BUTONU: (%.0f, %.0f)", pos.x, pos.y];
    [_statusOverlay setNeedsDisplay];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_statusOverlay.message = @"";
        [self->_statusOverlay setNeedsDisplay];
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)p {
    UIView *v = p.view;
    CGPoint trans = [p translationInView:v.superview];
    v.center = CGPointMake(v.center.x + trans.x, v.center.y + trans.y);
    [p setTranslation:CGPointZero inView:v.superview];
}

- (void)setupVolumeHook {
    NSError *err;
    [[AVAudioSession sharedInstance] setActive:YES error:&err];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&err];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(triggerPerfectCornerShot)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
}

// Mükemmel Kırmızı Şut İcrası (Native touchesBegan / touchesMoved / touchesEnded)
- (void)triggerPerfectCornerShot {
    // Buton basılma efekti
    [UIView animateWithDuration:0.06 animations:^{
        self->_shotBtn.transform = CGAffineTransformMakeScale(0.82, 0.82);
        self->_shotBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.85f blue:0.0f alpha:1.0f];
    } completion:^(BOOL fin) {
        [UIView animateWithDuration:0.06 animations:^{
            self->_shotBtn.transform = CGAffineTransformIdentity;
            self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.25f alpha:0.92f];
        }];
    }];

    UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
    if (!keyWin) return;

    UIViewController *fvc = [self findFlutterVC:keyWin.rootViewController];
    if (!fvc) return;

    // Hedef: Kalenin alt sol veya alt sağ direk köşesi
    _targetingRightCorner = !_targetingRightCorner;
    // Kaleye doğru çekim açısı: Sol direk (-0.75 radyan) / Sağ direk (-0.25 radyan)
    CGFloat angle = _targetingRightCorner ? -0.30f : -0.80f;
    CGFloat dragDist = 75.0f; // Tam kırmızı şut barı dolumu

    CGPoint startPt = _calibratedKickPos;
    CGPoint endPt = CGPointMake(startPt.x + dragDist * cosf(angle), startPt.y + dragDist * sinf(angle));

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    // 1. ADIM: Mavi şut butonuna dokun (touchesBegan)
    WpsMockTouch *touch = [[WpsMockTouch alloc] init];
    touch.customWindow = keyWin;
    touch.customView = fvc.view;
    touch.customLocation = startPt;
    touch.customPreviousLocation = startPt;
    touch.customPhase = UITouchPhaseBegan;
    touch.customTimestamp = now;

    [fvc touchesBegan:[NSSet setWithObject:touch] withEvent:nil];

    // 2. ADIM: Köşe direğe doğru sürükle (touchesMoved -> Aim Vector)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        touch.customPreviousLocation = startPt;
        touch.customLocation = endPt;
        touch.customPhase = UITouchPhaseMoved;
        touch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];

        [fvc touchesMoved:[NSSet setWithObject:touch] withEvent:nil];

        // 3. ADIM: Barın tam kırmızıya dolması (~0.35 saniye) ve bırakılması (touchesEnded -> 49.9999 Max Shot)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            touch.customPreviousLocation = endPt;
            touch.customLocation = endPt;
            touch.customPhase = UITouchPhaseEnded;
            touch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];

            [fvc touchesEnded:[NSSet setWithObject:touch] withEvent:nil];
        });
    });
}

@end

// ==========================================
// Method Swizzling: Şut Butonunu Otomatik Algılama
// ==========================================
@interface UIWindow (WpsTouchCapture)
@end

@implementation UIWindow (WpsTouchCapture)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [UIWindow class];
        SEL origSel = @selector(sendEvent:);
        SEL swizSel = @selector(wps_sendEvent:);
        Method origM = class_getInstanceMethod(cls, origSel);
        Method swizM = class_getInstanceMethod(cls, swizSel);
        if (origM && swizM) {
            method_exchangeImplementations(origM, swizM);
        }
    });
}

- (void)wps_sendEvent:(UIEvent *)event {
    [self wps_sendEvent:event];

    if (event.type == UIEventTypeTouches) {
        NSSet *touches = [event allTouches];
        for (UITouch *touch in touches) {
            // Sadece gerçek kullanıcı dokunuşlarını yakala (mock touch olmayanları)
            if (![touch isKindOfClass:[WpsMockTouch class]] && touch.phase == UITouchPhaseBegan) {
                CGPoint pt = [touch locationInView:self];
                CGSize scr = [UIScreen mainScreen].bounds.size;
                CGFloat w = MAX(scr.width, scr.height);
                CGFloat h = MIN(scr.width, scr.height);

                // Ekranın sağ alt çeyreğine dokunulduysa
                if (pt.x > (w * 0.55f) && pt.y > (h * 0.40f)) {
                    [[WpsShotManager sharedInstance] onKickButtonTouchedAt:pt];
                }
            }
        }
    }
}

@end

// ==========================================
// Entry Point
// ==========================================
__attribute__((constructor))
static void WpsInit(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[WpsShotManager sharedInstance] setupTweak];
    }];
}
