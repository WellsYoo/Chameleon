//  Created by Sean Heber on 8/31/10.
#import "UIMenuController.h"
#import "UIApplication.h"
#import "UIWindow+UIPrivate.h"
#import "UIScreen+UIPrivate.h"
#import "UIMenuItem.h"
#import <AppKit/NSMenu.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSApplication.h>

@interface UIMenuController () <NSMenuDelegate>
@end

@implementation UIMenuController
@synthesize menuItems=_menuItems;

+ (UIMenuController *)sharedMenuController
{
	static UIMenuController *controller = nil;
	return controller ?: (controller = [UIMenuController new]);
}

+ (NSArray *)_defaultMenuItems
{
	static NSArray *items = nil;

	if (!items) {
		items = [[NSArray alloc] initWithObjects:
				 [[[UIMenuItem alloc] initWithTitle:@"Cut" action:@selector(cut:)] autorelease],
				 [[[UIMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:)] autorelease],
				 [[[UIMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:)] autorelease],
				 [[[UIMenuItem alloc] initWithTitle:@"Delete" action:@selector(delete:)] autorelease],
				 [[[UIMenuItem alloc] initWithTitle:@"Select" action:@selector(select:)] autorelease],
				 [[[UIMenuItem alloc] initWithTitle:@"Select All" action:@selector(selectAll:)] autorelease],
				 nil];
	}

	return items;
}


- (id)init
{
	if ((self=[super init])) {
		_enabledMenuItems = [NSMutableArray new];
	}
	return self;
}

- (void)dealloc
{
	[_menuItems release];
	[_enabledMenuItems release];
	[_menu cancelTracking];		// this should never really happen since the controller is pretty much always a singleton, but... whatever.
	[_menu release];
	[super dealloc];
}

- (BOOL)isMenuVisible
{
	return (_menu != nil);
}

- (void)setMenuVisible:(BOOL)menuVisible animated:(BOOL)animated
{
	const BOOL wasVisible = [self isMenuVisible];

	if (menuVisible && !wasVisible) {
		[self update];

		if ([_enabledMenuItems count] > 0) {
			_menu = [[NSMenu alloc] initWithTitle:@""];
			[_menu setDelegate:self];
			[_menu setAutoenablesItems:NO];
			
			for (UIMenuItem *item in _enabledMenuItems) {
				NSMenuItem *theItem = [[NSMenuItem alloc] initWithTitle:item.title action:@selector(_didSelectMenuItem:) keyEquivalent:@""];
				[theItem setTarget:self];
				[theItem setRepresentedObject:item];
				[_menu addItem:theItem];
				[theItem release];
			}
			
			NSView *theNSView = [[UIApplication sharedApplication].keyWindow.screen _NSView];
			[NSMenu popUpContextMenu:_menu withEvent:[NSApp currentEvent] forView:theNSView];
		}
	} else if (!menuVisible && wasVisible) {
		// make it unhappen
		if (animated) {
			[_menu cancelTracking];
		} else {
			[_menu cancelTrackingWithoutAnimation];
		}
		[_menu release];
		_menu = nil;
	}
}

- (void)setMenuVisible:(BOOL)visible
{
	[self setMenuVisible:visible animated:NO];
}

- (void)setTargetRect:(CGRect)targetRect inView:(UIView *)targetView
{
}

- (void)update
{
	UIApplication *app = [UIApplication sharedApplication];
	UIResponder *firstResponder = [app.keyWindow _firstResponder];
	NSArray *allItems = [[isa _defaultMenuItems] arrayByAddingObjectsFromArray:_menuItems];

	[_enabledMenuItems removeAllObjects];

	if (firstResponder) {
		for (UIMenuItem *item in allItems) {
			if ([firstResponder canPerformAction:item.action withSender:app]) {
				[_enabledMenuItems addObject:item];
			}
		}
	}
}

- (void)_didSelectMenuItem:(NSMenuItem *)sender
{
	// the docs say that it calls -update when it detects a touch in the menu, so I assume it does this to try to prevent actions being sent
	// that perhaps have just been un-enabled due to something else that happened since the menu first appeared. To replicate that, I'll just
	// call update again here to rebuild the list of allowed actions and then do one final check to make sure that the requested action has
	// not been disabled out from under us.
	[self update];
	
	UIApplication *app = [UIApplication sharedApplication];
	UIResponder *firstResponder = [app.keyWindow _firstResponder];
	UIMenuItem *selectedItem = [sender representedObject];

	// now spin through the enabled actions, make sure the selected one is still in there, and then send it if it is.
	if (firstResponder && selectedItem) {
		for (UIMenuItem *item in _enabledMenuItems) {
			if (item.action == selectedItem.action) {
				[app sendAction:item.action to:firstResponder from:app forEvent:nil];
				break;
			}
		}
	}
}

- (void)menuDidClose:(NSMenu *)menu
{
	if (menu == _menu) {
		[_menu release];
		_menu = nil;
	}
}


@end