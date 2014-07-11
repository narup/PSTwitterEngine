PSTwitterEngine
===============

iOS library for twitter integration v1.1 API
## Steps to use
* Copy API_KEY & API_SECRET and paste it on Info.plist file
* Make sure you enable 'Login with twitter' on app settings page
* Use the following code to login and get user profile data.
* Please follow sample code for more details

```
- (IBAction)loginAction:(id)sender {
    
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
```
