#import "PassTime.h"

static NSString *kPassTimeIdentifier = @"com.insanj.passtime";
static NSString *kPassTimeDurationsIdentifier = @"PassTime.SavedDurations", *kPassTimeLastSelectedNameIdentifier = @"PassTime.Selected.Name", *kPassTimeLastSelectedRowIdentifier = @"PassTime.Selected.Row";

static HBPreferences *passTimePreferences;
static HBPreferences *getPassTimePreferences() {
	if (!passTimePreferences) {
		passTimePreferences = [[HBPreferences alloc] initWithIdentifier:kPassTimeIdentifier];
	}

	return passTimePreferences;
}

static NSString *kPassTimeImmediatelyText = [[NSBundle mainBundle] localizedStringForKey:@"IMMEDIATELY" value:@"Immediately" table:@"General"];
static NSString *kPassTimeGeneralText = [[NSBundle mainBundle] localizedStringForKey:@"General" value:@"General" table:@"General"];
static NSString *kPassTimePasscodeLockText = [[NSBundle mainBundle] localizedStringForKey:@"Passcode Lock" value:@"Passcode Lock" table:@"Passcode Lock"];
static NSString *kPassTimePasscodeMesaText = [[NSBundle mainBundle] localizedStringForKey:@"MESA" value:@"Touch ID & Passcode" table:@"Passcode Lock Mesa"];

static NSString *kPassTimePasscodeRequireText = [[NSBundle mainBundle] localizedStringForKey:@"PASSCODE_REQ" value:@"Require Passcode" table:@"Passcode Lock"];

static NSInteger kPassTimeAlertTag = 555;

#define LOCALIZE_STRING [[NSBundle mainBundle] localizedStringForKey:@"15_MINUTES" value:@"After %@ minutes" table:@"Passcode Lock"]
#define LOCALIZE(str) [NSString stringWithFormat:LOCALIZE_STRING, str]

%hook PSListController

- (void)viewWillAppear:(BOOL)animated {
	%orig();

	if ([self.navigationItem.title isEqualToString:kPassTimePasscodeLockText] || [self.navigationItem.title isEqualToString:kPassTimePasscodeMesaText]) {
		[self reloadSpecifiers];
	}
}

- (PSTableCell *)tableView:(UITableView *)arg1 cellForRowAtIndexPath:(NSIndexPath *)arg2 {
	PSTableCell *cell = %orig();
	NSString *lastSelectedTitle = (NSString *)[getPassTimePreferences() objectForKey:kPassTimeLastSelectedNameIdentifier default:nil];

	if (lastSelectedTitle && [cell.title isEqualToString:kPassTimePasscodeRequireText]) {
		cell.value = lastSelectedTitle;
	}

	return cell;
}

%end

%hook PSListItemsController

- (void)viewWillAppear:(BOOL)animated {
	%orig();
	
	if ([self.navigationItem.title isEqualToString:kPassTimePasscodeRequireText]) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(passtime_addButtonTapped:)];

		NSInteger lastSelectedRow = [getPassTimePreferences() integerForKey:kPassTimeLastSelectedRowIdentifier default:-1];
		if (lastSelectedRow > -1 && lastSelectedRow < [[self table] numberOfRowsInSection:0]) {
			[self tableView:[self table] didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:lastSelectedRow inSection:0]];
		}
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	%orig();

	HBPreferences *preferences = getPassTimePreferences();
	[preferences setInteger:indexPath.row forKey:kPassTimeLastSelectedRowIdentifier];
	[preferences setObject:[[((PSSpecifier *)[self itemsFromParent][indexPath.row+1]).shortTitleDictionary allValues] firstObject] forKey:kPassTimeLastSelectedNameIdentifier];
}

%new - (void)passtime_addButtonTapped:(UIBarButtonItem *)sender {
	UIAlertView *optionsPrompt = [[UIAlertView alloc] initWithTitle:@"PassTime" message:[LOCALIZE(@"How many") stringByAppendingString:@"?"] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Done", nil];
	optionsPrompt.alertViewStyle = UIAlertViewStylePlainTextInput;
	optionsPrompt.tag = kPassTimeAlertTag;

	UITextField *optionsPromptTextField = [optionsPrompt textFieldAtIndex:0];
	optionsPromptTextField.placeholder = @"e.g. 10, 15";
	optionsPromptTextField.keyboardType = UIKeyboardTypeNumberPad;

	[optionsPrompt show];
}

%new - (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (alertView.tag == kPassTimeAlertTag && buttonIndex != [alertView cancelButtonIndex]) {
		NSString *durationText = [alertView textFieldAtIndex:0].text;
		NSNumber *duration = @([durationText intValue] * 60);

		if (!duration) {
			[[[UIAlertView alloc] initWithTitle:[kPassTimePasscodeLockText stringByAppendingString:@" Duration Invalid"] message:[NSString stringWithFormat:@"The requested duration, \"%@\", is not a valid number", durationText] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
			return;
		}

		HBPreferences *preferences = getPassTimePreferences();
		NSArray *savedDurations = [preferences objectForKey:kPassTimeDurationsIdentifier default:nil];

		if (!savedDurations || ![savedDurations isKindOfClass:[NSArray class]]) {
			savedDurations = @[duration];
		}

		else if ([savedDurations containsObject:duration]) {
			NSMutableArray *duplicateRemovingDurations = [savedDurations mutableCopy];
			[duplicateRemovingDurations removeObject:duration];
			savedDurations = [NSArray arrayWithArray:duplicateRemovingDurations];
		}

		else {
			savedDurations = [@[duration] arrayByAddingObjectsFromArray:savedDurations];
		}

		NSMutableArray *sortedDurations = [savedDurations mutableCopy];
		[sortedDurations sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
		[preferences setObject:sortedDurations forKey:kPassTimeDurationsIdentifier];

		[self reloadSpecifiers];

		NSInteger lastSelectedRow = [getPassTimePreferences() integerForKey:kPassTimeLastSelectedRowIdentifier default:-1];
		if (lastSelectedRow >= 0) {
			[self tableView:[self table] didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:lastSelectedRow inSection:0]];
		}	
	}
}

- (id)itemsFromParent {
	NSArray *items = %orig();
	
	if ([self.navigationItem.title isEqualToString:kPassTimePasscodeRequireText]) {
		NSArray *appendableItems = items.count > 1 ? [items subarrayWithRange:NSMakeRange(0, items.count - 1)] : items;
		NSArray *savedTimes = (NSArray *)[getPassTimePreferences() objectForKey:kPassTimeDurationsIdentifier default:nil];
		if (savedTimes) {
			PSSpecifier *firstRealSpecifier = items.count > 0 ? items[1] : nil;

			for (int i = 0; i < savedTimes.count; i++){
				NSNumber *savedTime = (NSNumber *)savedTimes[i];
				NSString *savedTimeName = LOCALIZE(@([savedTime integerValue] / 60.0));

				PSSpecifier *savedTimeSpecifier = [PSSpecifier preferenceSpecifierNamed:savedTimeName target:[firstRealSpecifier target] set:MSHookIvar<SEL>(firstRealSpecifier, "setter") get:MSHookIvar<SEL>(firstRealSpecifier, "getter") detail:[firstRealSpecifier detailControllerClass] cell:[firstRealSpecifier cellType] edit:[firstRealSpecifier editPaneClass]];
				[savedTimeSpecifier setValues:@[savedTime]];
				[savedTimeSpecifier setTitleDictionary:@{savedTime : savedTimeName}];
				[savedTimeSpecifier setShortTitleDictionary:@{savedTime : savedTimeName}];
				appendableItems = [appendableItems arrayByAddingObject:savedTimeSpecifier];
			}	
		}
	
		return [appendableItems arrayByAddingObject:[items lastObject]];
	}

	return items;
}

%end
