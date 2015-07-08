//
//  ViewController.h
//  AvroClient
//
//  Created by Anthony Watkins on 7/9/12.
//  Copyright (c) 2012 Flurry, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AdDelegate.h"

@class AdNetworking;

@interface ViewController : UIViewController <AdDelegate> {
    UITextField*    _adSpaceName;
    UIButton*       _sendRequest;
    UITextView*    _responseText;
    UISegmentedControl* _version;
    UISegmentedControl* _method;
    
    AdNetworking*   _network;
}

@property (nonatomic, retain) IBOutlet UITextField  *adSpaceName;
@property (nonatomic, retain) IBOutlet UIButton     *sendRequest;
@property (nonatomic, retain) IBOutlet UITextView *responseText;
@property (nonatomic, retain) IBOutlet UISegmentedControl *version;
@property (nonatomic, retain) IBOutlet UISegmentedControl *method;
@property (nonatomic, retain) AdNetworking *network;

-(IBAction) sendRequestClickedButton:(id)sender;

@end
