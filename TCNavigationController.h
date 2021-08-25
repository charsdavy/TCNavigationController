//
//  TCNavigationController.h
//  Tally
//
//  Created by CHARS on 2019/7/15.
//  Copyright © 2019 chars. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^TCNavigationControllerCompletionBlock)(void);

extern NSString *const TCNavigationEdgeGestureDidChangedNotificationName;
extern NSString *const TCNavigationEdgeGestureEnableStatusKey;

@interface TCNavigationController : UIViewController

@property (nonatomic, strong) NSMutableArray *viewControllers;

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;

- (void)pushViewController:(UIViewController *)viewController;

- (void)pushViewController:(UIViewController *)viewController
                completion:(TCNavigationControllerCompletionBlock)completion;

- (void)popViewController;

- (void)popViewControllerCompletion:(TCNavigationControllerCompletionBlock)completion;

- (void)popToRootViewController;

- (void)popToViewController:(UIViewController *)toViewController;

@end

@interface UIViewController (TCNavigationController)

@property (nonatomic, strong) TCNavigationController *tcNavigationController;

@end
