    //
//  BaseTableViewController.m
//  iRedmine
//
//  Created by Thomas Stägemann on 05.04.11.
//  Copyright 2011 Weißhuhn & Weißhuhn Kommunikationsmanagement GmbH. All rights reserved.
//

#import "BaseTableViewController.h"

static const NSTimeInterval kBannerSlideInAnimationDuration = 0.5;

@implementation BaseTableViewController

@synthesize query=_query;

#pragma mark -
#pragma mark View lifecycle

- (id)initWithNavigatorURL:(NSURL *)URL query:(NSDictionary *)query {
	if (self = [super initWithNavigatorURL:URL query:query]) {
		[self setTableViewStyle:UITableViewStyleGrouped];
		[self setStatusBarStyle:UIStatusBarStyleDefault];
		[self setVariableHeightRows:YES];
		_query = [query retain];
	}
	return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];	
	[[self navigationController] setToolbarHidden:YES animated:animated];
}

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
    [super loadView];
		
	NSArray * purchases = [[NSUserDefaults standardUserDefaults] valueForKey:@"purchases"];
	if (!purchases || ![purchases containsObject:kInAppPurchaseIdentifierAdsFree]) {
		_adView = [[[ADBannerView alloc] initWithFrame: CGRectZero] retain];
		[_adView setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth];
		[_adView setRequiredContentSizeIdentifiers:[NSSet setWithObjects:ADBannerContentSizeIdentifier320x50,ADBannerContentSizeIdentifier480x32,nil]];
		[_adView setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifier320x50];
		[_adView setDelegate:self];
		[[self view] addSubview:_adView];
		[self updateViewFramesWithOrientation:[self interfaceOrientation] duration:0];
	}	
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
	[self updateViewFramesWithOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[self updateViewFramesWithOrientation:[self interfaceOrientation] duration:kBannerSlideInAnimationDuration];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return YES;
}

- (void)updateViewFramesWithOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration{
	if (!_adView) return;
	
	if (UIInterfaceOrientationIsLandscape(orientation))
		[_adView setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifier480x32];
	else
		[_adView setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifier320x50];
	
	[UIView beginAnimations:@"showBanner" context:NULL];
	[UIView setAnimationDuration:duration];
				
	if (_bannerIsVisible) {
		[[self tableView] setHeight:[[self view] height] - [_adView height]];
		[_adView setBottom:[[self view] bottom]];
	}
	else {
		[[self tableView] setHeight:[[self view] height]];
		[_adView setTop:[[self view] bottom]];
	}
	
	[UIView commitAnimations];
}

#pragma mark -
#pragma mark Memory management

- (void)viewDidUnload {
	[super viewDidUnload];
	[_adView setDelegate:nil];
	TT_RELEASE_SAFELY(_adView);
	TT_RELEASE_SAFELY(_query);
	
	_bannerIsVisible = NO;	
}

- (void)dealloc {
	[_adView setDelegate:nil];
	TT_RELEASE_SAFELY(_adView);
	TT_RELEASE_SAFELY(_query);
	
    [super dealloc];
}

#pragma mark -
#pragma mark AdViewBannerDelegate

- (void)bannerViewDidLoadAd:(ADBannerView *)banner {
	if (!_bannerIsVisible) {
		_bannerIsVisible = YES;
		[self updateViewFramesWithOrientation:[self interfaceOrientation] duration:kBannerSlideInAnimationDuration];
	}
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error {
	if (_bannerIsVisible) {
		_bannerIsVisible = NO;
		[self updateViewFramesWithOrientation:[self interfaceOrientation] duration:kBannerSlideInAnimationDuration];
	}
}

@end
