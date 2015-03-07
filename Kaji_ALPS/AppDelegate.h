//
//  AppDelegate.h
//  Kaji_ALPS
//
//  Created by haruhito on 2015/03/07.
//  Copyright (c) 2015年 Fuji Haruhito. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;


@end


#ifdef DEBUG
#define TRACE(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define TRACE(...)
#endif
