#include <unistd.h>
#include <sys/wait.h>
#import "AppDelegate.h"

int launch_ruby (char const* cmd)
{
	int pId, parentID = getpid();
	if((pId = fork()) == 0) // child
	{
		NSLog(@"set child (%d) to pgrp %d", getpid(), parentID);
		setpgrp(0, parentID);
		system(cmd);
		return 0;
	}
	else // parent
	{
		NSLog(@"started child process: %d", pId);
		return pId;
	}
}

@implementation AppDelegate

- (NSString*)storageDirectory
{
	NSString* dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Instiki"];
	[[NSFileManager defaultManager] createDirectoryAtPath:dir attributes:nil];
	return dir;
}

- (void)awakeFromNib
{
	setpgrp(0, getpid());

	if([[[[NSBundle mainBundle] infoDictionary] objectForKey:@"LSUIElement"] isEqualToString:@"1"])
	{
		NSStatusBar* bar = [NSStatusBar systemStatusBar];
		NSStatusItem* item = [[bar statusItemWithLength:NSVariableStatusItemLength] retain];
		[item setTitle:@"Wiki"];
		[item setHighlightMode:YES];
		[item setMenu:statusMenu];
	}

	NSBundle* bundle = [NSBundle bundleForClass:[self class]];
	NSString* ruby = [bundle pathForResource:@"ruby" ofType:nil];
	NSString* script = [[bundle resourcePath] stringByAppendingPathComponent:@"rb_src/instiki.rb"];
	if(ruby && script)
	{
		NSString* cmd = [NSString stringWithFormat:
			@"%@ -I '%@' -I '%@' '%@' -s --storage='%@'",
			ruby,
			[[bundle resourcePath] stringByAppendingPathComponent:@"lib/ruby/1.8"],
			[[bundle resourcePath] stringByAppendingPathComponent:@"lib/ruby/1.8/powerpc-darwin"],
			script,
			[self storageDirectory]
			];
		NSLog(@"starting %@", cmd);
		processID = launch_ruby([cmd UTF8String]);
	}

	/* public the service using rendezvous */
	service = [[NSNetService alloc]
		initWithDomain:@"" // default domain
		type:@"_http._tcp."
		name:[NSString stringWithFormat:@"%@'s Instiki", NSFullUserName()]
		port:2500];
	[service publish];
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
	[service stop];
	[service release];

	kill(0, SIGTERM);
}

- (IBAction)about:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:self];
}

- (IBAction)goToHomepage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://localhost:2500/"]];
}

- (IBAction)goToInstikiOrg:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.instiki.org/"]];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication*)sender
{
	return shouldOpenUntitled ?: (shouldOpenUntitled = YES, NO);
}

- (BOOL)applicationOpenUntitledFile:(NSApplication*)theApplication
{
	return [self goToHomepage:self], YES;
}

- (IBAction)quit:(id)sender
{
	[NSApp terminate:self];
}

@end
