//
//  ProjectViewController.m
//  iRedmine
//
//  Created by Thomas Stägemann on 14.04.09.
//  Copyright 2009 Thomas Stägemann. All rights reserved.
//

#import "ProjectViewController.h"

@interface ProjectViewController ()

@property (nonatomic) BOOL didAlreadyHandleReceive;

@end

@implementation ProjectViewController

@synthesize didAlreadyHandleReceive = _didAlreadyHandleReceive;

#pragma mark -
#pragma mark View lifecycle

- (id) initWithNavigatorURL:(NSURL *)URL query:(NSDictionary *)query{
	if (self = [super initWithNavigatorURL:URL query:query]) {		
		[self setTitle:NSLocalizedString(@"Project",@"")];	
		
		NSString * identifier = [query valueForKey:@"project"];
		NSString * path		  = [NSString stringWithFormat:@"projects/%@.xml?limit=100",identifier];
		NSURL * url			  = [NSURL URLWithString:[query valueForKey:@"url"]];
		NSString * URLString  = [[url absoluteString] stringByAppendingRelativeURL:path];

		// Legacy support
		NSString * legacyPath = [NSString stringWithFormat:@"projects/%@/issues",identifier];
		_atomFeed = [[[AtomFeed alloc] initWithURL:[url absoluteString] path:legacyPath xPath:@"//a[@class='atom' or @class='feed']"] retain];
		[_atomFeed setDelegate:self];
		[_atomFeed setDidFinishSelector:@selector(fetchFinished:)];
		[_atomFeed setDidFailSelector:@selector(fetchFailed:)];
		
		_request = [[RESTRequest requestWithURL:URLString delegate:self] retain];
		[_request setCachePolicy:TTURLRequestCachePolicyNoCache];
		[_request setHttpMethod:@"GET"];

		Account * account = [Account accountWithURL:[url absoluteString]];
		_login = [[Login loginWithURL:url username:[account username] password:[account password]] retain];
		[_login setDelegate:self];
		[_login setDidFinishSelector:@selector(loginFinished:)];
		[_login setDidFailSelector:@selector(loginFailed:)];
		
		
		_timeInfo = [TimeInformationRequest	withURL:[query valueForKey:@"url"]
										 forProject:[query valueForKey:@"project"]];
		_timeInfo.delegate = self;
		
		if (![_login start])
			[_request send];
	}
	return self;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (![_login start])
		[_request send];
}

#pragma mark - 
#pragma mark Atom feed selectors

- (void)fetchFinished:(AtomFeed*)feed {		
	id response = [[feed response] valueForKey:@"entry"];	
	if (!response) {
		[self setEmptyView:[[TTErrorView alloc] initWithTitle:NSLocalizedString(@"No issues found", @"") 
													 subtitle:nil
														image:nil]];
		return [self setLoadingView:nil];
	}
	
	BOOL isArray = [response isKindOfClass:[NSArray class]];
	NSArray * issues = isArray? response : [NSArray arrayWithObject:response];
	
	NSArray * featureTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FeatureCellTypes"];
	NSString * featurePattern = [NSString stringWithFormat:@".*(%@).*",[featureTypes componentsJoinedByString:@"|"]];
	
	NSArray * revisionTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"RevisionCellTypes"];
	NSString * revisionPattern = [NSString stringWithFormat:@".*(%@).*",[revisionTypes componentsJoinedByString:@"|"]];
	
	NSArray * errorTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"ErrorCellTypes"];
	NSString * errorPattern = [NSString stringWithFormat:@".*(%@).*",[errorTypes componentsJoinedByString:@"|"]];
	
	TTListDataSource * ds = [TTListDataSource dataSourceWithItems:[NSMutableArray array]];
	
	for (NSDictionary * issue in issues) {
		NSDate * timestamp = [NSDate dateFromXMLString:[issue valueForKeyPath:@"updated.___Entity_Value___"]];
		NSString * author = [issue valueForKeyPath:@"author.name.___Entity_Value___"];
		NSString * subject = [issue valueForKeyPath:@"title.___Entity_Value___"];
		NSString * URLString = [issue valueForKeyPath:@"link.href"];
		NSString * description = [[issue valueForKeyPath:@"content.___Entity_Value___"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if ([[issue valueForKeyPath:@"content.type"] isEqualToString:@"html"])
			description = [description stringByRemovingHTMLTags];
		
		NSString * imageURL = @"bundle://support.png";
		if ([subject matchedByPattern:featurePattern options:REG_ICASE])
			imageURL = @"bundle://feature.png";
		else if ([subject matchedByPattern:revisionPattern options:REG_ICASE])
			imageURL = @"bundle://revision.png";
		else if ([subject matchedByPattern:errorPattern options:REG_ICASE])
			imageURL = @"bundle://error.png";
		
		[[ds items] addObject:[TTTableMessageItem itemWithTitle:subject caption:author text:description timestamp:timestamp imageURL:imageURL URL:URLString]];
	}
	
	NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
	[[ds items] sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	
	[self setDataSource:ds];
}

- (void)fetchFailed:(AtomFeed*)feed {
	[self setLoadingView:nil];
	[self setErrorView:[[TTErrorView alloc] initWithTitle:NSLocalizedString(@"Connection Error", @"") 
												 subtitle:[[feed error] localizedDescription]
													image:nil]];	
}

#pragma mark - 
#pragma mark Login selectors

- (void)loginFinished:(Login*)login {
	[_request send];
}

- (void)loginFailed:(Login*)login {
	[self setLoadingView:nil];
	[self setErrorView:[[TTErrorView alloc] initWithTitle:NSLocalizedString(@"Authentication failed", @"") 
												 subtitle:[[login error] localizedDescription]
													image:nil]];	
}

#pragma mark -
#pragma mark Request delegate

- (void)request:(TTURLRequest*)request didFailLoadWithError:(NSError*)error {
	if ([error code] == 404)
		return [_atomFeed fetch];
	
	[self setLoadingView:nil];
	[self setErrorView:[[TTErrorView alloc] initWithTitle:TTLocalizedString(@"Connection Error", @"") 
												 subtitle:[error localizedDescription]
													image:nil]];
}

- (void)requestDidFinishLoad:(TTURLRequest*)request
{
	if (self.didAlreadyHandleReceive)
		return;
	self.didAlreadyHandleReceive = YES;
	
	NSDictionary * dict = [(TTURLXMLResponse *)[request response] rootObject];
	if (!dict) return;
	
	NSString * description = [dict valueForKeyPath:@"description.___Entity_Value___"];
	NSString * identifier  = [dict valueForKeyPath:@"identifier.___Entity_Value___"];
	NSString * projectName = [dict valueForKeyPath:@"name.___Entity_Value___"];
	NSString * updated	   = [[NSDate dateFromXMLString:[dict valueForKeyPath:@"updated_on.___Entity_Value___"]] formatRelativeTime];
	
	[self setTitle:projectName];	
	
	NSMutableDictionary * newQuery = [[self query] mutableCopy];
	[newQuery setObject:[NSString stringWithFormat:@"project_id=%@",identifier] forKey:@"params"];
	NSString * issuesURL = [@"iredmine://issues" stringByAddingQueryDictionary:newQuery];
	NSString * projectURL = [[[self query] valueForKey:@"url"] stringByAppendingRelativeURL:[NSString stringWithFormat:@"projects/%@",identifier]];

	TTSectionedDataSource * ds =[TTSectionedDataSource dataSourceWithObjects:
								 projectName,
								 [TTTableTextItem itemWithText:NSLocalizedString(@"Issues",@"")  URL:issuesURL],
								 @"",
								 [TTTableButton itemWithText:NSLocalizedString(@"Show in web view",@"") URL:projectURL],
								 @"",
								 [TTTableTextItem itemWithText:NSLocalizedString(@"Time management",@"") URL:@""],
								 [TTTableCaptionItem itemWithText:NSLocalizedString(@"Loading",@"") caption:NSLocalizedString(@"Spent",@"")],
								 [TTTableCaptionItem itemWithText:NSLocalizedString(@"Loading",@"") caption:NSLocalizedString(@"Estimated",@"")],
								 @"",
								 [TTTableGrayTextItem itemWithText:[NSString stringWithFormat:TTLocalizedString(@"Last updated: %@", @""),updated]],
								 nil];

	if (description && TTIsStringWithAnyText(description))
		[[[ds items] objectAtIndex:0] insertObject:[TTTableLongTextItem itemWithText:description] atIndex:0];
	
	Account * account = [Account accountWithURL:[[self query] valueForKey:@"url"]];
	if ([account username] && [account password]) {
		NSString * addURL = [@"iredmine://issue/add" stringByAddingQueryDictionary:[self query]];
		[[[ds items] objectAtIndex:1] addObject:[TTTableButton itemWithText:NSLocalizedString(@"New issue",@"") URL:addURL]];
	}

	[self setDataSource:ds];
	[_timeInfo start];
}

#pragma mark -
#pragma mark Updated Estimated and Spent time

- (NSMutableArray *) timeSection
{
	TTSectionedDataSource * ds = self.dataSource;
	return [[ds items] objectAtIndex:2];
}

- (void) setTimeEstimated:(double)timeEstimated andSpent:(double)timeSpent
{
	NSString * estimated = [NSString stringWithFormat:NSLocalizedString(@"%0.1f hours",@""),timeEstimated];
	NSString * spent = [NSString stringWithFormat:NSLocalizedString(@"%0.1f hours",@""),timeSpent];

	NSMutableArray * timeSection = [self timeSection];
	[[timeSection objectAtIndex:1] setText:spent];
	[[timeSection objectAtIndex:2] setText:estimated];

	[self refresh];
}

- (void) fetchingTimeInfoFailed
{
	NSString * failedText = NSLocalizedString(@"Failed", @"");

	NSMutableArray * timeSection = [self timeSection];
	[[timeSection objectAtIndex:1] setText:failedText];
	[[timeSection objectAtIndex:2] setText:failedText];
	
	[self refresh];
}

#pragma mark -
#pragma mark Memory management

- (void) dealloc {
	[_login setDelegate:nil];
	[_login cancel];
	TT_RELEASE_SAFELY(_login);
	
	[_request cancel];
	TT_RELEASE_SAFELY(_request);

	[_timeInfo cancel];
	TT_RELEASE_SAFELY(_timeInfo);

	[super dealloc];
}

@end
