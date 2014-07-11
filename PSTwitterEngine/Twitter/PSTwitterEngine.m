//
//  TwitterEngine.m
//  IntoMovies
//
//  Created by Puran Singh on 2/23/14.
//  Copyright (c) 2014 Puran Singh. All rights reserved.
//

#import "PSTwitterEngine.h"
#import "TWSignedRequest.h"
#import "OAuthCore.h"

NSString *const kTW_CONSUMER_KEY                              = @"TWITTER_CONSUMER_KEY";
NSString *const kTW_CONSUMER_SECRET                           = @"TWITTER_CONSUMER_SECRET";


NSString *const kAPI_BASE_URL                                 = @"https://api.twitter.com";

NSString *const kPATH_OAUTH_CALLBACK                          = @"pstwitterengine://twitter";
NSString *const kPATH_REQUEST_TOKEN                           = @"/oauth/request_token";
NSString *const kPATH_ACCESS_TOKEN                            = @"/oauth/access_token";
NSString *const kPATH_APP_AUTHENTICATE                        = @"/oauth/authenticate";

NSString *const kUSER_PROFILE_PATH                            = @"/1.1/users/show.json";
NSString *const kUSER_FRIENDS_PATH                            = @"/1.1/followers/list.json";
NSString *const kSEND_MESSAGE_PATH                            = @"/1.1/direct_messages/new.json";

NSString *const kTWEET_STATUS                                 = @"/1.1/statuses/update.json";

NSString *const kHTTP_HEADER_AUTHORIZATION                    = @"Authorization";
NSInteger const kREQUEST_TIMEOUT_INTERVAL                     = 60;

static NSString *consumerKey;
static NSString *consumerSecret;

typedef void(^TwitterAuthComplete)(NSString *userID, NSString *userName, NSError *error);

@interface PSTwitterEngine ()
@property (nonatomic, strong) NSURLSession  *networkSession;

@property (nonatomic, strong) NSArray               *friends;
@property (nonatomic, copy) TwitterAuthComplete     twitterAuthComplete;
@property (nonatomic, strong) NSString              *screenName;
@property (nonatomic, strong) NSString              *authToken;
@property (nonatomic, strong) NSString              *authTokenSecret;
@property (nonatomic, strong) NSString              *authTokenVerifier;
@end

@implementation PSTwitterEngine

+ (PSTwitterEngine *)sharedEngine {
    static PSTwitterEngine *sharedEngine = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedEngine = [[PSTwitterEngine alloc] init];
    });
    return sharedEngine;
}

- (id)init {
    self = [super init];
    if (self) {
        self.networkSession = [NSURLSession sharedSession];
    }
    return self;
}

- (void)logout {
    self.authToken = nil;
    self.authTokenSecret = nil;
    
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for(NSHTTPCookie *cookie in [storage cookies]) {
        if ([cookie.domain isEqualToString:@".twitter.com"]) {
            [storage deleteCookie:cookie];
        }
    }
}

- (NSString *)oAuthToken {
    return [self.authToken copy];
}

- (NSString *)oAuthSecret {
    return [self.authTokenSecret copy];
}

- (BOOL)isLoggedIn {
    return (_authToken != nil && _authTokenSecret != nil && _screenName != nil);
}

- (void)twitterLogin:(void (^)(NSString *userID, NSString *userName, NSError *error))completionHandler {
    self.twitterAuthComplete = [completionHandler copy];
    [self requestToken:^(NSString *requestToken, NSError *error) {
        if (error || !requestToken) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.twitterAuthComplete (nil, nil, error);
                self.twitterAuthComplete = nil;
            });
        } else {
            [[UIApplication sharedApplication] openURL:[[PSTwitterEngine sharedEngine] twitterLoginURL]];
        }
    }];
}

- (void)requestToken:(void (^)(NSString *requestToken, NSError *error))completionHandler {
    NSURL *requestTokenURL = [self requestTokenURL];
    NSData *bodyData = nil;
    NSString *method = @"POST";
    
    NSString *authorizationHeader = OAuthorizationHeaderWithCallback(requestTokenURL,
                                                                     method,
                                                                     bodyData,
                                                                     [PSTwitterEngine consumerKey],
                                                                     [PSTwitterEngine consumerSecret],
                                                                     _authToken,
                                                                     _authTokenSecret,
                                                                     kPATH_OAUTH_CALLBACK);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestTokenURL];
    [request setTimeoutInterval:kREQUEST_TIMEOUT_INTERVAL];
    [request setHTTPMethod:method];
    
    [request setValue:authorizationHeader forHTTPHeaderField:kHTTP_HEADER_AUTHORIZATION];
    [request setHTTPBody:bodyData];
    
    __weak typeof (self) weakSelf = self;
    NSURLSessionDataTask *postDataTask =
        [self.networkSession dataTaskWithRequest:request
                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                   NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                                   if (error || httpResp.statusCode != 200) {
                                       completionHandler (nil, error);
                                   } else {
                                       NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                       NSLog(@"Twitter API Response:%@", responseData);
                                       if (responseData) {
                                           NSDictionary *keyValuePair = [weakSelf splitResponseToKeyValuePairs:responseData];
                                           self.authToken = [keyValuePair objectForKey:@"oauth_token"];
                                           self.authTokenSecret = [keyValuePair objectForKey:@"oauth_token_secret"];
                                           BOOL callbackConfirm = [[keyValuePair objectForKey:@"oauth_callback_confirmed"] boolValue];
                                           if (!callbackConfirm) {
                                               completionHandler (nil, [NSError errorWithDomain:@"ERROR" code:1001 userInfo:nil]);
                                           } else {
                                               completionHandler (weakSelf.authToken, nil);
                                           }
                                       } else {
                                           completionHandler (nil, [NSError errorWithDomain:@"ERROR" code:1001 userInfo:nil]);
                                       }
                                   }
    }];
    [postDataTask resume];
}

- (void)fetchAccessToken {
    NSURL *accessTokenURL = [self accessTokenURL];
    NSString *oAuthVerifierData = [NSString stringWithFormat:@"oauth_verifier=%@", self.authTokenVerifier];
    NSData *bodyData = [oAuthVerifierData dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *method = @"POST";
    NSString *authorizationHeader = OAuthorizationHeader(accessTokenURL,
                                                         method,
                                                         bodyData,
                                                         [PSTwitterEngine consumerKey],
                                                         [PSTwitterEngine consumerSecret],
                                                         _authToken,
                                                         _authTokenSecret);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:accessTokenURL];
    [request setTimeoutInterval:kREQUEST_TIMEOUT_INTERVAL];
    [request setHTTPMethod:method];
    
    [request setValue:authorizationHeader forHTTPHeaderField:kHTTP_HEADER_AUTHORIZATION];
    [request setHTTPBody:bodyData];
    
    __weak typeof (self) weakSelf = self;
    NSURLSessionDataTask *postDataTask =
                    [self.networkSession dataTaskWithRequest:request
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                               NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                               if (error || httpResp.statusCode != 200) {
                                   weakSelf.twitterAuthComplete (nil, nil, error);
                               } else {
                                   NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                   NSLog(@"Twitter API Response:%@", responseData);
                                   if (responseData) {
                                       NSDictionary *keyValuePair = [weakSelf splitResponseToKeyValuePairs:responseData];
                                       
                                       weakSelf.authToken = [keyValuePair objectForKey:@"oauth_token"];
                                       weakSelf.authTokenSecret = [keyValuePair objectForKey:@"oauth_token_secret"];
                                       
                                       NSString *userID = [keyValuePair objectForKey:@"user_id"];
                                       NSString *userName = [keyValuePair objectForKey:@"screen_name"];
                                       weakSelf.screenName = userName;
                                      
                                       weakSelf.twitterAuthComplete (userID, userName, nil);
                                       weakSelf.twitterAuthComplete = nil;
                                   } else {
                                       weakSelf.twitterAuthComplete(nil, nil, [NSError errorWithDomain:@"ERROR" code:1001 userInfo:nil]);
                                       weakSelf.twitterAuthComplete = nil;
                                   }
                               }
                           }];
    [postDataTask resume];
}

- (void)profileDataForUser:userName
         completionHandler:(void (^)(NSDictionary *userProfile, NSError *error))completionHandler {
    
    NSURL *profileURL = [self profileURLForUser:userName];
    NSData *bodyData = nil;
    
    NSString *method = @"GET";
    NSString *authorizationHeader = OAuthorizationHeader(profileURL,
                                                         method,
                                                         bodyData,
                                                         [PSTwitterEngine consumerKey],
                                                         [PSTwitterEngine consumerSecret],
                                                         _authToken,
                                                         _authTokenSecret);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:profileURL];
    [request setTimeoutInterval:kREQUEST_TIMEOUT_INTERVAL];
    [request setHTTPMethod:method];
    
    [request setValue:authorizationHeader forHTTPHeaderField:kHTTP_HEADER_AUTHORIZATION];
    [request setHTTPBody:bodyData];
    
    NSURLSessionDataTask *postDataTask =
    [self.networkSession dataTaskWithRequest:request
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                               NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                               if (error || httpResp.statusCode != 200) {
                                   if (error)
                                       completionHandler (nil, error);
                                   else
                                       completionHandler (nil, [NSError errorWithDomain:@"Client Eror" code:-1001 userInfo:nil]);
                               } else {
                                   NSDictionary *responseData = [self responseJSON:data];
                                   NSLog(@"Response :%@", responseData);
                                   completionHandler (responseData, nil);
                               }
                           }];
    [postDataTask resume];
}

- (void)friendsForUser:userName
     completionHandler:(void (^)(NSArray *friends, NSError *error))completionHandler {
    
    if (self.friends && [self.friends count] > 0) {
        completionHandler (self.friends, nil);
        return;
    }
    
    NSData *bodyData = nil;
    NSURL *friendsGetURL = [self friendsGetURL:userName];
    NSString *method = @"GET";
    NSString *authorizationHeader = OAuthorizationHeader(friendsGetURL,
                                                         method,
                                                         bodyData,
                                                         [PSTwitterEngine consumerKey],
                                                         [PSTwitterEngine consumerSecret],
                                                         _authToken,
                                                         _authTokenSecret);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:friendsGetURL];
    [request setTimeoutInterval:kREQUEST_TIMEOUT_INTERVAL];
    [request setHTTPMethod:method];
    
    [request setValue:authorizationHeader forHTTPHeaderField:kHTTP_HEADER_AUTHORIZATION];
    [request setHTTPBody:bodyData];
    
    __weak typeof (self) weakSelf = self;
    NSURLSessionDataTask *postDataTask =
    [self.networkSession dataTaskWithRequest:request
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                                   if (error || httpResp.statusCode != 200) {
                                       completionHandler (nil, error);
                                   } else {
                                       NSDictionary *responseData = [self responseJSON:data];
                                       NSLog(@"Response :%@", responseData);
                                       weakSelf.friends = [responseData objectForKey:@"users"];
                                       completionHandler (weakSelf.friends, nil);
                                   }
                               });
                           }];
    [postDataTask resume];
}

- (void)tweetMessage:(NSString *)message completionHandler:(void (^)(NSError *error))completionHandler {
    NSString *encodedMessage = [self urlEncode:message usingEncoding:NSUTF8StringEncoding];
    NSString *postStringData = [NSString stringWithFormat:@"status=%@", encodedMessage];
    
    NSData *bodyData = [postStringData dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *tweetStatusStringURL = [NSString stringWithFormat:@"%@%@", kAPI_BASE_URL, kTWEET_STATUS];
    NSURL *tweetURL = [NSURL URLWithString:tweetStatusStringURL];
    
    NSString *method = @"POST";
    NSString *authorizationHeader = OAuthorizationHeader(tweetURL,
                                                         method,
                                                         bodyData,
                                                         [PSTwitterEngine consumerKey],
                                                         [PSTwitterEngine consumerSecret],
                                                         _authToken,
                                                         _authTokenSecret);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:tweetURL];
    [request setTimeoutInterval:kREQUEST_TIMEOUT_INTERVAL];
    [request setHTTPMethod:method];
    
    [request setValue:authorizationHeader forHTTPHeaderField:kHTTP_HEADER_AUTHORIZATION];
    [request setHTTPBody:bodyData];
    
    NSURLSessionDataTask *postDataTask =
    [self.networkSession dataTaskWithRequest:request
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                                   if (error || httpResp.statusCode != 200) {
                                       completionHandler (error);
                                   } else {
                                       completionHandler (nil);
                                   }
                               });
                           }];
    [postDataTask resume];
    
}

- (void)sendDirectMessageToFriend:(NSString *)friendScreenName completionHandler:(void (^)(NSError *error))completionHandler {
    NSString *message = @"Hello, I am using PSTwitterEngine";
    
    NSString *encodedMessage = [self urlEncode:message usingEncoding:NSUTF8StringEncoding];
    NSString *postStringData = [NSString stringWithFormat:@"text=%@&screen_name=%@", encodedMessage, friendScreenName];
    
    NSData *bodyData = [postStringData dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *messageURL = [self directMessageURL];
    
    NSString *method = @"POST";
    NSString *authorizationHeader = OAuthorizationHeader(messageURL,
                                                         method,
                                                         bodyData,
                                                         [PSTwitterEngine consumerKey],
                                                         [PSTwitterEngine consumerSecret],
                                                         _authToken,
                                                         _authTokenSecret);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:messageURL];
    [request setTimeoutInterval:kREQUEST_TIMEOUT_INTERVAL];
    [request setHTTPMethod:method];
    
    [request setValue:authorizationHeader forHTTPHeaderField:kHTTP_HEADER_AUTHORIZATION];
    [request setHTTPBody:bodyData];
    
    NSURLSessionDataTask *postDataTask =
    [self.networkSession dataTaskWithRequest:request
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                                   if (error || httpResp.statusCode != 200) {
                                       completionHandler (error);
                                   } else {
                                       completionHandler (nil);
                                   }
                               });
                           }];
    [postDataTask resume];
}

- (NSDictionary *)splitResponseToKeyValuePairs:(NSString *)responseData {
    NSMutableDictionary *keyValue = [NSMutableDictionary dictionary];
    for (NSString *token in [responseData componentsSeparatedByString:@"&"]) {
        NSArray *pair = [token componentsSeparatedByString:@"="];
        if (pair && [pair count] == 2)
            [keyValue setObject:[pair objectAtIndex:1] forKey:[pair objectAtIndex:0]];
    }
    return [keyValue copy];
}

- (NSURL *)twitterLoginURL {
    NSString *loginURL = [NSString stringWithFormat:@"%@%@?oauth_token=%@", kAPI_BASE_URL, kPATH_APP_AUTHENTICATE, self.authToken];
    return [NSURL URLWithString:loginURL];
}

- (BOOL)handleOpenURL:(NSURL *)openURL {
    NSString *tokenData = [openURL query];
    NSDictionary *keyValuePair = [self splitResponseToKeyValuePairs:tokenData];

    NSString *oauthToken = [keyValuePair objectForKey:@"oauth_token"];
    self.authTokenVerifier = [keyValuePair objectForKey:@"oauth_verifier"];
    
    if (oauthToken && self.authTokenVerifier && [oauthToken isEqualToString:self.authToken]) {
        [self fetchAccessToken];
        
        return YES;
    }
    return NO;
}

#pragma mark - Utility methods

- (NSURL *)friendsGetURL:(NSString *)screenName {
    NSString *friendsURL = [NSString stringWithFormat:@"%@%@?screen_name=%@&count=200&skip_status=t&cursor=-1", kAPI_BASE_URL, kUSER_FRIENDS_PATH, screenName];
    return [NSURL URLWithString:friendsURL];
}

- (NSURL *)directMessageURL {
    NSString *directMessageURL = [NSString stringWithFormat:@"%@%@", kAPI_BASE_URL, kSEND_MESSAGE_PATH];
    return [NSURL URLWithString:directMessageURL];
}

- (NSURL *)requestTokenURL {
    NSString *requestTokenURLString = [NSString stringWithFormat:@"%@%@", kAPI_BASE_URL, kPATH_REQUEST_TOKEN];
    return [NSURL URLWithString:requestTokenURLString];
}

- (NSURL *)accessTokenURL {
    NSString *accessTokenURLString = [NSString stringWithFormat:@"%@%@", kAPI_BASE_URL, kPATH_ACCESS_TOKEN];
    return [NSURL URLWithString:accessTokenURLString];
}

- (NSURL *)profileURLForUser:(NSString *)userName {
    NSString *profileURLString = [NSString stringWithFormat:@"%@%@?screen_name=%@", kAPI_BASE_URL, kUSER_PROFILE_PATH, userName];
    return [NSURL URLWithString:profileURLString];
}

- (NSDictionary *)responseJSON:(NSData *)data {
    NSError *jsonError;
    NSDictionary *responseJSON = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:NSJSONReadingAllowFragments
                                                                   error:&jsonError];
    return responseJSON;
}

-(NSString *)urlEncode:(NSString *)string usingEncoding:(NSStringEncoding)encoding {
    CFStringRef urlRef = CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                 (CFStringRef)string,
                                                                 NULL,
                                                                 (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                 CFStringConvertNSStringEncodingToEncoding(encoding));
	NSString *stringURL = (__bridge_transfer NSString *)urlRef;
    return stringURL;
}

+ (NSString *)consumerKey {
    if (!consumerKey) {
        NSBundle* bundle = [NSBundle mainBundle];
        consumerKey = bundle.infoDictionary[kTW_CONSUMER_KEY];
    }
    
    return consumerKey;
}

// OBFUSCATE YOUR KEYS!
+ (NSString *)consumerSecret {
    if (!consumerSecret) {
        NSBundle* bundle = [NSBundle mainBundle];
        consumerSecret = bundle.infoDictionary[kTW_CONSUMER_SECRET];
    }
    
    return consumerSecret;
}


@end
