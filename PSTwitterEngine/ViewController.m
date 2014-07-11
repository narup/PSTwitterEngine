//
//  ViewController.m
//  PSTwitterEngine
//
//  Created by Puran Singh on 7/11/14.
//  Copyright (c) 2014 32skills. All rights reserved.
//

#import "ViewController.h"
#import "PSTwitterEngine.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)loginAction:(id)sender {
    UIActivityIndicatorView *busyIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:busyIndicator];
    busyIndicator.center = self.view.center;
    
    [busyIndicator startAnimating];
    [[PSTwitterEngine sharedEngine] twitterLogin:^(NSString *userID, NSString *userName, NSError *error) {
        if (error) {
            [self showError:error];
        } else {
            [[PSTwitterEngine sharedEngine] profileDataForUser:userName completionHandler:^(NSDictionary *userProfile, NSError *error) {
                if (error) {
                    [self showError:error];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [busyIndicator removeFromSuperview];
                        self.userData.text = [userProfile description];
                    });
                }
            }];
        }
    }];
}

- (void)showError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *errorView = [[UIAlertView alloc] initWithTitle:@"ERROR" message:[error description] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [errorView show];
    });
}
@end
