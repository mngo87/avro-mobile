//
//  ViewController.m
//  AvroClient
//
//  Created by Anthony Watkins on 7/9/12.
//  Copyright (c) 2012 Flurry, Inc. All rights reserved.
//

#import "ViewController.h"
#import "AdNetworking.h"

@implementation ViewController

@synthesize adSpaceName     = _adSpaceName;
@synthesize sendRequest     = _sendRequest;
@synthesize responseText    = _responseText;
@synthesize network         = _network;
@synthesize version         = _version;
@synthesize method          = _method;

-(void) dealloc {
    self.adSpaceName = nil;
    self.sendRequest = nil;
    self.responseText = nil;
    self.network = nil;
    self.version = nil;
    self.method = nil;
    [super dealloc];
}

-(IBAction) sendRequestClickedButton:(id)sender {
    [self.adSpaceName resignFirstResponder];
    
    NSLog(@"Request clicked with adSpace name %@", self.adSpaceName.text);
    
    if (_network != nil) {
        NSLog(@"Currently processing request");
        return;
    }
    
    // Send Ad Request
    _network = [[AdNetworking alloc] init];
    _network.delegate = self;
    NSLog(@"adSpaceName=%@ version=%d method=%d",
          self.adSpaceName.text,
          _version.selectedSegmentIndex,
          _method.selectedSegmentIndex);
    
    [_network updateUserPrefRequest:34 checkInEnabled:true tempVar:999 brakeAudio:false];
    //[_network sendAdRequest:self.adSpaceName.text lat:45.123 lon:-75.456];
}

- (void)adResponseReceived:(NSString *)response {
    self.responseText.text = response;
}

- (void)adRequestDidFinsih {
    self.network = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
