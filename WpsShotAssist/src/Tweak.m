#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>

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
// Status Toast Overlay (Bildirim & Geri Bildirim)
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
    CGRect bannerRect = CGRectMake(scr.width / 2.0f - 200.0f, 10.0f, 400.0f, 28.0f);
    
    // Yarı saydam yuvarlatılmış siyah arka plan
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:bannerRect cornerRadius:6.0f];
    CGContextSetRGBFillColor(ctx, 0.0, 0.0, 0.0, 0.82);
    [path fill];

    // Kırmızı/Altın çerçeve
    CGContextSetRGBStrokeColor(ctx, 1.0, 0.2, 0.2, 0.95);
    CGContextSetLineWidth(ctx, 1.2);
    [path stroke];

    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:12.5f],
        NSForegroundColorAttributeName: [UIColor colorWithRed:1.0f green:0.9f blue:0.2f alpha:1.0f]
    };
    
    CGSize textSz = [self.message sizeWithAttributes:attrs];
    CGRect textRect = CGRectMake(bannerRect.origin.x + (bannerRect.size.width - textSz.width) / 2.0f,
                                 bannerRect.origin.y + (bannerRect.size.height - textSz.height) / 2.0f,
                                 textSz.width, textSz.height);
    [self.message drawInRect:textRect withAttributes:attrs];
}
@end

// ==========================================
// Tweak Manager
// ==========================================
@interface WpsShotManager : NSObject
+ (instancetype)sharedInstance;
- (void)setupTweak;
- (void)onKickButtonTouchedAt:(CGPoint)pos;
- (void)executeShotToRightCorner:(BOOL)targetRight;
- (void)toggleAttackDirection;
@end

@implementation WpsShotManager {
    UIButton *_shotBtn;
    UILabel *_directionLabel;
    WpsStatusOverlay *_statusOverlay;
    BOOL _targetingRightCorner;
    BOOL _attackDirectionDown; // NO = Üst Kale (Default), YES = Alt Kale
    CGPoint _calibratedKickPos;
    BOOL _isCalibrated;
    BOOL _isShooting;
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

- (void)showToast:(NSString *)msg duration:(NSTimeInterval)sec {
    if (!_statusOverlay) return;
    _statusOverlay.message = msg;
    [_statusOverlay setNeedsDisplay];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearToast) object:nil];
    [self performSelector:@selector(clearToast) withObject:nil afterDelay:sec];
}

- (void)clearToast {
    if (_statusOverlay) {
        _statusOverlay.message = @"";
        [_statusOverlay setNeedsDisplay];
    }
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

        // Canlı maç görüntüsünden tespit edilen kesin pozisyon: (761, 212)
        self->_calibratedKickPos = CGPointMake(761.0f, 212.0f);
        self->_isCalibrated = YES;
        self->_attackDirectionDown = NO; // Varsayılan: Üst Kale

        // Bilgilendirme Banner Katmanı
        if (!self->_statusOverlay) {
            self->_statusOverlay = [[WpsStatusOverlay alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            [keyWin addSubview:self->_statusOverlay];
            [self showToast:@"[WPS] ⚡ TAM KIRMIZI 90 ŞUT HAZIR (L: Sol 90 | R: Sağ 90)" duration:4.0];
        }

        // ⚡SHOT Butonu (Kırmızı / Altın Daire)
        if (!self->_shotBtn) {
            CGFloat btnSize = 70.0f;
            self->_shotBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            self->_shotBtn.frame = CGRectMake(w - 85.0f, h / 2.0f - 35.0f, btnSize, btnSize);
            self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.92f green:0.10f blue:0.18f alpha:0.95f];
            self->_shotBtn.layer.cornerRadius = btnSize / 2.0f;
            self->_shotBtn.layer.borderWidth = 2.5f;
            self->_shotBtn.layer.borderColor = [UIColor whiteColor].CGColor;
            self->_shotBtn.layer.shadowColor = [UIColor blackColor].CGColor;
            self->_shotBtn.layer.shadowOffset = CGSizeMake(0, 3);
            self->_shotBtn.layer.shadowOpacity = 0.6f;
            self->_shotBtn.layer.shadowRadius = 5.0f;

            // İçerik Başlıkları
            UILabel *topLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, btnSize, 20)];
            topLbl.text = @"⚡SHOT";
            topLbl.font = [UIFont boldSystemFontOfSize:14.0f];
            topLbl.textColor = [UIColor whiteColor];
            topLbl.textAlignment = NSTextAlignmentCenter;
            topLbl.userInteractionEnabled = NO;
            [self->_shotBtn addSubview:topLbl];

            UILabel *subLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 28, btnSize, 14)];
            subLbl.text = @"◀ L | R ▶";
            subLbl.font = [UIFont boldSystemFontOfSize:10.5f];
            subLbl.textColor = [UIColor colorWithRed:1.0f green:0.85f blue:0.15f alpha:1.0f];
            subLbl.textAlignment = NSTextAlignmentCenter;
            subLbl.userInteractionEnabled = NO;
            [self->_shotBtn addSubview:subLbl];

            self->_directionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 46, btnSize, 14)];
            self->_directionLabel.text = @"🔴 MAX 49";
            self->_directionLabel.font = [UIFont boldSystemFontOfSize:9.0f];
            self->_directionLabel.textColor = [UIColor colorWithWhite:0.95 alpha:1.0];
            self->_directionLabel.textAlignment = NSTextAlignmentCenter;
            self->_directionLabel.userInteractionEnabled = NO;
            [self->_shotBtn addSubview:self->_directionLabel];

            // Tıklama Olayı (Sol yarı = Sol 90, Sağ yarı = Sağ 90)
            [self->_shotBtn addTarget:self action:@selector(handleShotBtnTapped:forEvent:) forControlEvents:UIControlEventTouchUpInside];

            // Sürükleyip Taşıma (Pan)
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
            [self->_shotBtn addGestureRecognizer:pan];

            // Uzun Basma: Kale Yönünü Değiştir (Üst ⬆️ <-> Alt ⬇️)
            UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
            lp.minimumPressDuration = 0.45;
            [self->_shotBtn addGestureRecognizer:lp];

            [keyWin addSubview:self->_shotBtn];
        }

        // Fiziksel Ses Açma Tuşu Hook
        [self setupVolumeHook];
    });
}

- (void)onKickButtonTouchedAt:(CGPoint)pos {
    _calibratedKickPos = pos;
    _isCalibrated = YES;
    [self showToast:[NSString stringWithFormat:@"🎯 ŞUT BUTONU GÜNCELLENDİ: (%.0f, %.0f)", pos.x, pos.y] duration:2.5];
}

- (void)handlePan:(UIPanGestureRecognizer *)p {
    UIView *v = p.view;
    CGPoint trans = [p translationInView:v.superview];
    v.center = CGPointMake(v.center.x + trans.x, v.center.y + trans.y);
    [p setTranslation:CGPointZero inView:v.superview];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)lp {
    if (lp.state == UIGestureRecognizerStateBegan) {
        [self toggleAttackDirection];
    }
}

- (void)toggleAttackDirection {
    _attackDirectionDown = !_attackDirectionDown;
    AudioServicesPlaySystemSound(1519); // Peek haptic feedback

    NSString *dirText = _attackDirectionDown ? @"⬇️ HEDEF: ALT KALE" : @"⬆️ HEDEF: ÜST KALE";
    [self showToast:[NSString stringWithFormat:@"🔄 HEDEF KALE DEĞİŞTİ: %@", dirText] duration:2.5];
}

- (void)handleShotBtnTapped:(UIButton *)btn forEvent:(UIEvent *)event {
    UITouch *t = [[event touchesForView:btn] anyObject];
    CGPoint loc = [t locationInView:btn];

    // Butonun sol yarısına basıldıysa Sol Köşe, sağ yarısına basıldıysa Sağ Köşe
    BOOL targetRight = (loc.x >= btn.bounds.size.width / 2.0f);
    [self executeShotToRightCorner:targetRight];
}

- (void)setupVolumeHook {
    NSError *err;
    [[AVAudioSession sharedInstance] setActive:YES error:&err];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&err];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onVolumeTrigger)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
}

- (void)onVolumeTrigger {
    // Ses tuşuna basıldığında köşeleri sırayla dene
    _targetingRightCorner = !_targetingRightCorner;
    [self executeShotToRightCorner:_targetingRightCorner];
}

// ==========================================
// Mükemmel 100% Kırmızı Bar 90'a Şut İcrası
// ==========================================
- (void)executeShotToRightCorner:(BOOL)targetRight {
    if (_isShooting) return; // Çakışmayı önle
    _isShooting = YES;

    // Buton basılma animasyonu (Şarj esnasında sarıdan kırmızıya geçiş)
    self->_shotBtn.transform = CGAffineTransformMakeScale(0.85, 0.85);
    self->_shotBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.85f blue:0.0f alpha:1.0f];

    UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
    if (!keyWin) {
        _isShooting = NO;
        return;
    }

    UIViewController *fvc = [self findFlutterVC:keyWin.rootViewController];
    if (!fvc) {
        _isShooting = NO;
        return;
    }

    // GEOMETRİ & GÜÇ KALİBRASYONU:
    // Kale yönü: Üst kale için dy negatif (-82.0f), Alt kale için dy pozitif (+82.0f)
    // Direk açısı: Sol köşe dx = -20.0f, Sağ köşe dx = +20.0f
    // Vektör mesafesi: sqrt(20^2 + 82^2) = 84.4f (Joystick limitini 100% zorlar)
    CGFloat dx = targetRight ? 20.0f : -20.0f;
    CGFloat dy = _attackDirectionDown ? 82.0f : -82.0f;

    CGPoint startPt = _calibratedKickPos;
    CGPoint endPt = CGPointMake(startPt.x + dx, startPt.y + dy);

    NSString *cornerName = targetRight ? @"SAĞ 90" : @"SOL 90";
    NSString *kaleName = _attackDirectionDown ? @"ALT KALE" : @"ÜST KALE";
    [self showToast:[NSString stringWithFormat:@"🔴 TAM GÜÇ ŞUT ŞARJ OLUYOR: %@ %@...", kaleName, cornerName] duration:1.5];

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    // 1. ADIM: Şut butonunun merkezine bas (touchesBegan)
    WpsMockTouch *touch = [[WpsMockTouch alloc] init];
    touch.customWindow = keyWin;
    touch.customView = fvc.view;
    touch.customLocation = startPt;
    touch.customPreviousLocation = startPt;
    touch.customPhase = UITouchPhaseBegan;
    touch.customTimestamp = now;

    [fvc touchesBegan:[NSSet setWithObject:touch] withEvent:nil];

    // 2. ADIM: Köşe direğe doğru joysticki sonuna kadar çek (touchesMoved)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        touch.customPreviousLocation = startPt;
        touch.customLocation = endPt;
        touch.customPhase = UITouchPhaseMoved;
        touch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];
        [fvc touchesMoved:[NSSet setWithObject:touch] withEvent:nil];

        // Şarj sırasında butonu kırmızıya çevir
        [UIView animateWithDuration:0.40 animations:^{
            self->_shotBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:1.0f];
        }];

        // Flutter Ticker şarjının takılmaması için ara dokunuş akışı (250ms & 500ms)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            touch.customPreviousLocation = endPt;
            touch.customLocation = endPt;
            touch.customPhase = UITouchPhaseMoved;
            touch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];
            [fvc touchesMoved:[NSSet setWithObject:touch] withEvent:nil];
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.50 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            touch.customPreviousLocation = endPt;
            touch.customLocation = endPt;
            touch.customPhase = UITouchPhaseMoved;
            touch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];
            [fvc touchesMoved:[NSSet setWithObject:touch] withEvent:nil];
        });

        // 3. ADIM: Bar 100% Tam Kırmızıya (Max 49.9999 Hız) ulaştığında (0.80 saniye) şutu ateşle (touchesEnded)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.80 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            touch.customPreviousLocation = endPt;
            touch.customLocation = endPt;
            touch.customPhase = UITouchPhaseEnded;
            touch.customTimestamp = [NSDate timeIntervalSinceReferenceDate];

            [fvc touchesEnded:[NSSet setWithObject:touch] withEvent:nil];

            // Efektleri sıfırla
            [UIView animateWithDuration:0.10 animations:^{
                self->_shotBtn.transform = CGAffineTransformIdentity;
                self->_shotBtn.backgroundColor = [UIColor colorWithRed:0.92f green:0.10f blue:0.18f alpha:0.95f];
            }];

            AudioServicesPlaySystemSound(1520); // Ağır vuruş haptic feedback
            [self showToast:[NSString stringWithFormat:@"🚀 GOL! TAM KIRMIZI 49.9999 %@ 🎯", cornerName] duration:2.0];
            self->_isShooting = NO;
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

                // Ekranın sağ alt çeyreğindeki şut alanına dokunulduysa konumu güncelle
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
