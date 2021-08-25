//
//  TCNavigationController.m
//  Tally
//
//  Created by CHARS on 2019/7/15.
//  Copyright © 2019 chars. All rights reserved.
//  https://github.com/charsdavy/TCNavigationController
//

#import "TCNavigationController.h"

static const CGFloat TCAnimationDuration = 0.35;   // Push / Pop 动画持续时间
static const CGFloat TCMaxBlackMaskAlpha = 0.8;   // 黑色背景透明度
static const CGFloat TCZoomRatio         = 1.0;   // 后面视图缩放比
static const CGFloat TCShadowOpacity     = 0.8;   // 滑动返回时当前视图的阴影透明度
static const CGFloat TCShadowRadius      = 8.0;   // 滑动返回时当前视图的阴影半径

typedef enum : NSUInteger {
    EdgeDirectionNone,
    EdgeDirectionLeft,
    EdgeDirectionRight,
} EdgeDirection;

NSString *const TCNavigationEdgeGestureDidChangedNotificationName = @"TCNavigationEdgeGestureDidChangedNotification";
NSString *const TCNavigationEdgeGestureEnableStatusKey = @"TCNavigationEdgeGestureEnableStatus";

@interface TCNavigationController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) NSMutableArray *gestures;
@property (nonatomic,   weak) UIView *blackMask;
@property (nonatomic, assign) BOOL animationing;
@property (nonatomic, assign) CGPoint panOrigin;
@property (nonatomic, assign) CGFloat percentageOffsetFromLeft;
/// 中断左滑手势操作
@property (nonatomic, assign) BOOL breakEdgeGesture;

@end

@implementation TCNavigationController

- (void)dealloc
{
    self.viewControllers = nil;
    self.gestures  = nil;
    self.blackMask = nil;
    self.breakEdgeGesture = NO;
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
{
    if (self = [super init]) {
        self.viewControllers = [NSMutableArray arrayWithObject:rootViewController];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(edgeGestureDidChanged:) name:TCNavigationEdgeGestureDidChangedNotificationName object:nil];
    }
    return self;
}

- (CGRect)viewBoundsWithOrientation:(UIInterfaceOrientation)orientation
{
    CGRect bounds = [UIScreen mainScreen].bounds;
    
    if ([[UIApplication sharedApplication]isStatusBarHidden]) {
        return bounds;
    } else if (UIInterfaceOrientationIsLandscape(orientation)) {
        CGFloat width = bounds.size.width;
        bounds.size.width = bounds.size.height;
        bounds.size.height = width;
        
        return bounds;
    } else {
        return bounds;
    }
}

- (void)loadView
{
    [super loadView];
    
    CGRect viewRect = [self viewBoundsWithOrientation:UIApplication.sharedApplication.statusBarOrientation];
    
    UIViewController *rootViewController = [self.viewControllers firstObject];
    [rootViewController willMoveToParentViewController:self];
    [self addChildViewController:rootViewController];
    
    UIView *rootView = rootViewController.view;
    rootView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    rootView.frame = viewRect;
    [self.view addSubview:rootView];
    [rootViewController didMoveToParentViewController:self];
    
    UIView *blackMask = [[UIView alloc] initWithFrame:viewRect];
    blackMask.backgroundColor = [UIColor blackColor];
    blackMask.alpha = 0;
    blackMask.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view insertSubview:blackMask atIndex:0];
    self.blackMask = blackMask;
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
}

- (UIViewController *)currentViewController
{
    UIViewController *result = nil;
    if (self.viewControllers.count) result = [self.viewControllers lastObject];
    return result;
}

- (UIViewController *)previousViewController
{
    UIViewController *result = nil;
    if (self.viewControllers.count > 1) {
        result = [self.viewControllers objectAtIndex:self.viewControllers.count - 2];
    }
    return result;
}

- (void)addEdgeGestureToView:(UIView *)view
{
    UIScreenEdgePanGestureRecognizer *edgeGesture = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(gestureRecognizerDidEdge:)];
    edgeGesture.delegate = self;
    edgeGesture.edges = UIRectEdgeLeft;
    [view addGestureRecognizer:edgeGesture];
    [self.gestures addObject:edgeGesture];
}

- (void)gestureRecognizerDidEdge:(UIPanGestureRecognizer *)edgeGesture
{
    if (self.breakEdgeGesture || self.animationing) {
        return;
    }
    
    CGPoint currentPoint = [edgeGesture translationInView:self.view];
    CGFloat x = currentPoint.x + self.panOrigin.x;
    
    EdgeDirection edgeDirection = EdgeDirectionNone;
    CGPoint vel = [edgeGesture velocityInView:self.view];
    
    if (vel.x > 0) {
        edgeDirection = EdgeDirectionRight;
    } else {
        edgeDirection = EdgeDirectionLeft;
    }
    
    CGFloat offset = 0;
    
    UIViewController *vc = [self currentViewController];
    offset = CGRectGetWidth(vc.view.frame) - x;
    vc.view.layer.shadowColor   = [UIColor blackColor].CGColor;
    vc.view.layer.shadowOpacity = TCShadowOpacity;
    vc.view.layer.shadowRadius  = TCShadowRadius;
    
    self.percentageOffsetFromLeft = offset / [self viewBoundsWithOrientation:UIApplication.sharedApplication.statusBarOrientation].size.width;
    vc.view.frame = [self getSlidingRectWithPercentageOffset:self.percentageOffsetFromLeft orientation:UIApplication.sharedApplication.statusBarOrientation];
    [self transformAtPercentage:self.percentageOffsetFromLeft];
    
    if (edgeGesture.state == UIGestureRecognizerStateEnded || edgeGesture.state == UIGestureRecognizerStateCancelled) {
        if (fabs(vel.x) > 100) {
            [self completeSlidingAnimationWithDirection:edgeDirection];
        } else {
            [self completeSlidingAnimationWithOffset:offset];
        }
    }
}

- (void)completeSlidingAnimationWithDirection:(EdgeDirection)direction
{
    if (direction == EdgeDirectionRight) {
        [self popViewController];
    } else {
        [self rollBackViewController];
    }
}

- (void)completeSlidingAnimationWithOffset:(CGFloat)offset
{
    if (offset < [self viewBoundsWithOrientation:UIApplication.sharedApplication.statusBarOrientation].size.width * 0.5f) {
        [self popViewController];
    } else {
        [self rollBackViewController];
    }
}

- (void)rollBackViewController
{
    self.animationing = YES;
    
    UIViewController *vc = [self currentViewController];
    UIViewController *nvc = [self previousViewController];
    CGRect rect = CGRectMake(0, 0, vc.view.frame.size.width, vc.view.frame.size.height);
    
    [UIView animateWithDuration:0.3f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        CGAffineTransform transf = CGAffineTransformIdentity;
        nvc.view.transform = CGAffineTransformScale(transf, TCZoomRatio, TCZoomRatio);
        vc.view.frame = rect;
        self.blackMask.alpha = TCMaxBlackMaskAlpha;
    } completion:^(BOOL finished) {
        if (finished) {
            self.animationing = NO;
        }
    }];
}

- (CGRect)getSlidingRectWithPercentageOffset:(CGFloat)percentage orientation:(UIInterfaceOrientation)orientation
{
    CGRect viewRect = [self viewBoundsWithOrientation:orientation];
    CGRect rectToReturn = CGRectZero;
    rectToReturn.size = viewRect.size;
    rectToReturn.origin = CGPointMake(MAX(0, (1 - percentage) * viewRect.size.width), 0);
    
    return rectToReturn;
}

- (void)transformAtPercentage:(CGFloat)percentage
{
    CGAffineTransform transf = CGAffineTransformIdentity;
    CGFloat newTransformValue =  1 - percentage * (1 - TCZoomRatio);
    CGFloat newAlphaValue = percentage * TCMaxBlackMaskAlpha;
    [self previousViewController].view.transform = CGAffineTransformScale(transf, newTransformValue, newTransformValue);
    
    self.blackMask.alpha = newAlphaValue;
}

- (void)pushViewController:(UIViewController *)viewController completion:(TCNavigationControllerCompletionBlock)completion
{
    self.animationing = YES;
    
    viewController.view.layer.shadowColor   = [UIColor blackColor].CGColor;
    viewController.view.layer.shadowOpacity = TCShadowOpacity;
    viewController.view.layer.shadowRadius  = TCShadowRadius;
    
    viewController.view.frame = CGRectOffset(self.view.bounds, self.view.bounds.size.width, 0);
    viewController.view.autoresizingMask =  UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.blackMask.alpha = 0;
    [viewController willMoveToParentViewController:self];
    [self addChildViewController:viewController];
    
    [self.view bringSubviewToFront:self.blackMask];
    [self.view addSubview:viewController.view];
    
    [UIView animateWithDuration:TCAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        CGAffineTransform transf = CGAffineTransformIdentity;
        [self currentViewController].view.transform = CGAffineTransformScale(transf, TCZoomRatio, TCZoomRatio);
        viewController.view.frame = self.view.bounds;
        self.blackMask.alpha = TCMaxBlackMaskAlpha;
    } completion:^(BOOL finished) {
        if (finished) {
            [self.viewControllers addObject:viewController];
            [viewController didMoveToParentViewController:self];
            
            self.animationing = NO;
            self.gestures = [[NSMutableArray alloc] init];
            [self addEdgeGestureToView:[self currentViewController].view];
            
            if (completion != nil) completion();
        }
    }];
}

- (void)pushViewController:(UIViewController *)viewController
{
    [self pushViewController:viewController completion:nil];
}

- (void)popViewControllerCompletion:(TCNavigationControllerCompletionBlock)completion
{
    if (self.viewControllers.count < 2) return;
    
    self.animationing = YES;
    
    UIViewController *currentVC = [self currentViewController];
    UIViewController *previousVC = [self previousViewController];
    [previousVC viewWillAppear:NO];
    
    currentVC.view.layer.shadowColor   = [UIColor blackColor].CGColor;
    currentVC.view.layer.shadowOpacity = TCShadowOpacity;
    currentVC.view.layer.shadowRadius  = TCShadowRadius;
    
    [UIView animateWithDuration:TCAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        currentVC.view.frame = CGRectOffset(self.view.bounds, self.view.bounds.size.width, 0);
        CGAffineTransform transf = CGAffineTransformIdentity;
        previousVC.view.transform = CGAffineTransformScale(transf, 1.0f, 1.0f);
        previousVC.view.frame = self.view.bounds;
        self.blackMask.alpha = 0;
    } completion:^(BOOL finished) {
        if (finished) {
            [currentVC.view removeFromSuperview];
            [currentVC willMoveToParentViewController:nil];
            
            [self.view bringSubviewToFront:[self previousViewController].view];
            [currentVC removeFromParentViewController];
            [currentVC didMoveToParentViewController:nil];
            
            [self.viewControllers removeObject:currentVC];
            self.animationing = NO;
            [previousVC viewDidAppear:NO];
            
            if (completion != nil) completion();
        }
    }];
}

- (void)popViewController
{
    [self popViewControllerCompletion:nil];
}

- (void)popToViewController:(UIViewController *)toViewController
{
    NSMutableArray *controllers = self.viewControllers;
    NSInteger index = [controllers indexOfObject:toViewController];
    UIViewController *needRemoveViewController = nil;
    
    for (int i = (int)controllers.count - 2; i > index; i--) {
        needRemoveViewController = [controllers objectAtIndex:i];
        [needRemoveViewController.view setAlpha:0];
        
        [needRemoveViewController removeFromParentViewController];
        [controllers removeObject:needRemoveViewController];
    }
    
    [self popViewController];
}

- (void)popToRootViewController
{
    UIViewController *rootController = [self.viewControllers objectAtIndex:0];
    [self popToViewController:rootController];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    UIViewController *current = [self currentViewController];
    if (current) {
        return [current preferredStatusBarStyle];
    }
    return UIStatusBarStyleDefault;
}

- (void)edgeGestureDidChanged:(NSNotification *)noti
{
    NSDictionary *userInfo = noti.userInfo;
    if ([userInfo.allKeys containsObject:TCNavigationEdgeGestureEnableStatusKey]) {
        BOOL status = [[userInfo objectForKey:TCNavigationEdgeGestureEnableStatusKey] boolValue];
        self.breakEdgeGesture = !status;
    }
}

@end

@implementation UIViewController (TCNavigationController)

@dynamic tcNavigationController;

- (TCNavigationController *)tcNavigationController
{
    UIResponder *responder = [self nextResponder];
    
    while (responder) {
        if ([responder isKindOfClass:[TCNavigationController class]]) {
            return (TCNavigationController *)responder;
        }
        
        responder = [responder nextResponder];
    }
    
    return nil;
}

@end
