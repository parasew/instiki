/* AppDelegate */

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject
{
	IBOutlet NSMenu* statusMenu;
	NSTask* serverCommand;
	int processID;
	BOOL shouldOpenUntitled;

	NSNetService* service;
}
- (IBAction)about:(id)sender;
- (IBAction)goToHomepage:(id)sender;
- (IBAction)goToInstikiOrg:(id)sender;
- (IBAction)quit:(id)sender;
@end
