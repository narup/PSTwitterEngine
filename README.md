PSTwitterEngine
===============

iOS library for twitter integration v1.1 API

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
