//
//  TwitterEngine.h
//  IntoMovies
//
//  Created by Puran Singh on 2/23/14.
//  Copyright (c) 2014 Puran Singh. All rights reserved.
//
@interface PSTwitterEngine : NSObject

// You should ensure that you obfuscate your keys before shipping
+ (NSString *)consumerKey;
+ (NSString *)consumerSecret;
+ (PSTwitterEngine *)sharedEngine;

- (NSString *)oAuthToken;
- (NSString *)oAuthSecret;


- (void)logout;
- (BOOL)isLoggedIn;
- (void)twitterLogin:(void (^)(NSString *userID, NSString *userName, NSError *error))completionHandler;
- (void)profileDataForUser:userName completionHandler:(void (^)(NSDictionary *userProfile, NSError *error))completionHandler;
- (void)friendsForUser:userName
     completionHandler:(void (^)(NSArray *friends, NSError *error))completionHandler;
- (BOOL)handleOpenURL:(NSURL *)openURL;
- (void)sendDirectMessageToFriend:(NSString *)friendScreenName completionHandler:(void (^)(NSError *error))completionHandler;
- (void)tweetMessage:(NSString *)message completionHandler:(void (^)(NSError *error))completionHandler;
@end
