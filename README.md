PSTwitterEngine
===============

iOS library for twitter integration v1.1 API
### Steps to use
* Create twitter application on developer.twitter.com
* Copy API_KEY & API_SECRET and paste it on your application's Info.plist file with keys TWITTER_CONSUMER_KEY & TWITTER_CONSUMER_SECRET
* Make sure you enable 'Login with twitter' on app settings page
* Use the following code to login and get user profile data.

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

### Make sure you override this method in your AppDelegate.m
```
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    NSLog(@"Handle Application URL:%@", url.absoluteString);
    return [[PSTwitterEngine sharedEngine] handleOpenURL:url];
}
```

### Other operations supported
```
- (void)logout;
- (BOOL)isLoggedIn;
- (void)twitterLogin:(void (^)(NSString *userID, NSString *userName, NSError *error))completionHandler;
- (void)profileDataForUser:userName completionHandler:(void (^)(NSDictionary *userProfile, NSError *error))completionHandler;
- (void)friendsForUser:userName
     completionHandler:(void (^)(NSArray *friends, NSError *error))completionHandler;
- (BOOL)handleOpenURL:(NSURL *)openURL;
- (void)sendDirectMessageToFriend:(NSString *)friendScreenName completionHandler:(void (^)(NSError *error))completionHandler;
- (void)tweetMessage:(NSString *)message completionHandler:(void (^)(NSError *error))completionHandler;
```
