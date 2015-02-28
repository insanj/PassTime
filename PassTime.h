#import <UIKit/UIKit.h>
#import <Cephei/HBPreferences.h>
#import <Preferences/Preferences.h>
#import "substrate.h"

#ifdef DEBUG
    #define LOG(fmt, ...) NSLog((@"[PassTime] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
    #define LOG(fmt, ...) 
#endif

@interface PSListItemsController (PassTime) <UIAlertViewDelegate>

- (void)passtime_addButtonTapped:(UIBarButtonItem *)sender;

@end
