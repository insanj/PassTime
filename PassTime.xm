#import "PassTime.h"
#define NSStringFromBool(a) a?@"are":@"aren't"

#define PTPREFS_PATH [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/PassTime"]
#define PTPREFS_PLIST [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/PassTime/SavedDurations.plist"]
#define PTLAST_PLIST [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/PassTime/LastSelected.plist"]
#define PTDEFAULT_TITLES @[@"Immediately", @"After 1 minute", @"After 5 minutes", @"After 15 minutes", @"After 1 hour", @"After 4 hours"]

@interface PTAlertViewDelegate : NSObject <UIAlertViewDelegate>
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
@end

@implementation PTAlertViewDelegate
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	if(buttonIndex != 0){
		NSString *durationText = [alertView textFieldAtIndex:0].text;
		NSNumber *duration = [NSNumber numberWithInt:[durationText intValue] * 60];
		if(!duration || [duration intValue] <= 60){
			[[[UIAlertView alloc] initWithTitle:@"Passcode Duration Invalid" message:[NSString stringWithFormat:@"The requested duration, %@, is invalid. Make sure your requests are new, minute-long durations, nothing more or less.", durationText] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
			return;
		}

		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSDictionary *finalized;
		BOOL isDuplicate = NO;
		if(![fileManager fileExistsAtPath:PTPREFS_PLIST]){
			NSDictionary *newPrefs = @{[duration stringValue] : [NSString stringWithFormat:@"After %@ minutes", durationText]};
			finalized = newPrefs;
		}

		else{
			NSDictionary *savedPrefs = [NSDictionary dictionaryWithContentsOfFile:PTPREFS_PLIST];
			isDuplicate = [[savedPrefs allKeys] containsObject:[duration stringValue]];
			NSMutableDictionary *newPrefs = [[NSMutableDictionary alloc] init];

			for(NSString *key in [savedPrefs allKeys])
				if(![key isEqualToString:[duration stringValue]] && ![newPrefs objectForKey:key])
					[newPrefs setObject:[savedPrefs objectForKey:key] forKey:key];
			
			if(!isDuplicate)
				[newPrefs setObject:[NSString stringWithFormat:@"After %@ minutes", durationText] forKey:[duration stringValue]];

			finalized = newPrefs;
		}

		NSLog(@"[PassTime]: Wrote the augmented specifier plist (%@) to file %@.", finalized, PTPREFS_PLIST);
		[finalized writeToFile:PTPREFS_PLIST atomically:YES];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"PTAddSpecifier" object:nil userInfo:@{@"PTTitle" : [NSString stringWithFormat:@"After %@ minutes", durationText]}];

		if(isDuplicate && alertView.tag == [durationText intValue])
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"PTReselectSpecifier" object:nil];
	}
}
@end

@interface PSListController (PassTime)
-(void)passtime_promptUserForSpecifier;
-(void)passtime_addSpecifierForNotification:(NSNotification *)notification;
-(void)passtime_reselectSpecifier;
@end

%hook PSListController
static PTAlertViewDelegate *ptdelegate;

-(void)viewWillAppear:(BOOL)animated{
	%orig();

	if([self.navigationItem.title rangeOfString:@"Passcode"].location != NSNotFound)
		[self reloadSpecifiers];

	if([self.navigationItem.title isEqualToString:@"Require Passcode"]){
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(passtime_promptUserForSpecifier)];
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(passtime_addSpecifierForNotification:) name:@"PTAddSpecifier" object:nil];
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(passtime_reselectSpecifier) name:@"PTReselectSpecifier" object:nil];

		NSError *error;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if(![fileManager fileExistsAtPath:PTPREFS_PATH])
			[fileManager createDirectoryAtPath:PTPREFS_PATH withIntermediateDirectories:YES attributes:nil error:&error];

		else{
			NSDictionary *savedPrefs = [NSDictionary dictionaryWithContentsOfFile:PTLAST_PLIST];
			int row = [savedPrefs[@"PTLastIndexPath"] intValue];

			if([self tableView:[self table] numberOfRowsInSection:0] > row)
				[self tableView:[self table] didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
		}
	}//end if
}

-(PSTableCell *)tableView:(UITableView *)arg1 cellForRowAtIndexPath:(NSIndexPath *)arg2{
	PSTableCell *cell = %orig();
	if([cell.title isEqualToString:@"Require Passcode"] && [NSDictionary dictionaryWithContentsOfFile:PTLAST_PLIST] != nil)
		for(UIView *subview in cell.contentView.subviews)
			if([subview isKindOfClass:[%c(UITableViewLabel) class]])
				[(UITableViewLabel *)subview setText:[NSDictionary dictionaryWithContentsOfFile:PTLAST_PLIST][@"PTLastText"]];

	return cell;
}

-(void)viewWillDisappear:(BOOL)animated{
	if([self.navigationItem.title isEqualToString:@"Require Passcode"]){
		[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];

		for(int i = 0; i < [[self table] numberOfRowsInSection:0]; i++){
			PSTableCell *cell = (PSTableCell *)[[self table] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
			if(cell.accessoryType == UITableViewCellAccessoryCheckmark){
				[@{@"PTLastIndexPath" : @(i), @"PTLastText" : cell.title} writeToFile:PTLAST_PLIST atomically:YES];
				break;
			}
		}
	}//end if

	%orig();
}

%new -(void)passtime_promptUserForSpecifier{
	NSLog(@"[PassTime]: Prompting user for additional specifier creation.");

	ptdelegate = [[PTAlertViewDelegate alloc] init];
	UIAlertView *ptalertview = [[UIAlertView alloc] initWithTitle:@"Modify Passcode Requirements" message:@"Enter your desired requirement duration in minutes to add it, or an already-existing duration to remove it, then tap Done." delegate:ptdelegate cancelButtonTitle:@"Cancel" otherButtonTitles:@"Done", nil];
	[ptalertview setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [[ptalertview textFieldAtIndex:0] setPlaceholder:@"e.g. 10, 30"];
    [[ptalertview textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeNumberPad];

    for(int i = 0; i < [[self table] numberOfRowsInSection:0]; i++){
    	PSTableCell *cell = (PSTableCell *)[[self table] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
    	if(cell.accessoryType == UITableViewCellAccessoryCheckmark)
    		ptalertview.tag = [[[cell title] componentsSeparatedByString:@" "][0] intValue];
    }

    [ptalertview show];
}

%new -(void)passtime_addSpecifierForNotification:(NSNotification *)notification{
	NSLog(@"[PassTime]: Refreshing tableView (%@) for given specifier title: %@", [self table], [notification userInfo][@"PTTitle"]);
	[self reloadSpecifiers];

   for(int i = 0; i < [[self table] numberOfRowsInSection:0]; i++){
    	PSTableCell *cell = (PSTableCell *)[[self table] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
    	if([[cell title] isEqualToString:[notification userInfo][@"PTTitle"]]){
			[self tableView:[self table] didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
			return;
    	}
   }
}

%new -(void)passtime_reselectSpecifier{
	[self tableView:[self table] didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
}

%end

@interface PSListItemsController (PassTime)
-(void)passtime_addFooterToView;
@end

%hook PSListItemsController
static PTAlertViewDelegate *ptdeleteDelegate;

-(id)itemsFromParent{
	NSArray *items = %orig();
	PSSpecifier *first = items.count > 0?items[1]:nil;
	BOOL inPasscode = first && [first.name isEqualToString:@"Immediately"];

	NSLog(@"[PassTime] Received call to -itemsFromParent, appears we %@ in Require Passcode pane (%@)", NSStringFromBool(inPasscode), self);
	
	if(inPasscode){
		NSMutableArray *additional = [[NSMutableArray alloc] init];
		for(int i = 0; i < items.count - 1; i++)
			[additional addObject:items[i]];

		NSDictionary *savedPrefs = [NSDictionary dictionaryWithContentsOfFile:PTPREFS_PLIST];

		if(savedPrefs){
			for(int i = [savedPrefs allKeys].count - 1; i >= 0; i--){
				NSString *key = [[savedPrefs allKeys] objectAtIndex:i];
				NSNumber *val = [NSNumber numberWithInt:[key intValue]];
				NSString *name = [savedPrefs objectForKey:key];

				PSSpecifier *newSpecifier = [PSSpecifier preferenceSpecifierNamed:name target:[first target] set:MSHookIvar<SEL>(first, "setter") get:MSHookIvar<SEL>(first, "getter") detail:[first detailControllerClass] cell:[first cellType] edit:[first editPaneClass]];
				[newSpecifier setValues:@[val]];
				[newSpecifier setTitleDictionary:@{val : name}];
				[newSpecifier setShortTitleDictionary:@{val : name}];

				NSLog(@"[PassTime] Modifying requested specifier with name:%@ and value:%@, raw:%@", name, val, newSpecifier);
				[additional addObject:newSpecifier];
			}	
		}
	
		[additional addObject:[items lastObject]];
		items = [[NSArray alloc] initWithArray:additional];
		
		NSLog(@"[PassTime] Finished augmenting specifiers (%@) to create: %@", savedPrefs, items);
	}

	return items;
}

%end