//
//  PushSyncManager.m
//  Push
//
//  Created by Christopher Guess on 11/11/15.
//  Copyright © 2015 OCCRP. All rights reserved.
//

#import "PushSyncManager.h"
#import "SettingsManager.h"
#import "LanguageManager.h"
#import "AnalyticsManager.h"
#import <AFNetworking/AFNetworking.h>
#include "Reachability.h"

typedef enum : NSUInteger {
    PushSyncArticles,
    PushSyncArticle,
    PushSyncSearch,
} PushSyncRequestType;

@interface TempRequest : NSObject

@property (nonatomic, assign) PushSyncRequestType type;
@property (nonatomic, copy) CompletionBlock completionHandler;
@property (nonatomic, copy) FailureBlock failureBlock;
@property (nonatomic, readwrite) NSDictionary * requestParameters;

@end

@implementation TempRequest
@end

struct Request {
};


@interface PushSyncManager() {
    BOOL _unreachable;
}

@property (nonatomic, retain) id articles;
@property (nonatomic, retain) NSOperationQueue * priorityQueue;

@property (nonatomic, retain) NSURLSession * session;

@property (nonatomic, retain) NSMutableArray * torRequests;

@property (atomic, assign) BOOL unreachable;
@property (atomic, assign) BOOL startingUp;

// Checks if the service is reachable
- (BOOL)checkInternetReachability;

@end

@implementation PushSyncManager

static const NSString * versionNumber = @"1.1";

dispatch_semaphore_t _sem;

+ (PushSyncManager *)sharedManager {
    static PushSyncManager *_sharedManager = nil;
    
    //We only want to create one singleton object, so do that with GCD
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //Set up the singleton class
        _sharedManager = [[PushSyncManager alloc] init];
        // Testing for tor
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [_sharedManager checkInternetReachability];
        });
    });
    
    return _sharedManager;
}

//+ (PushSyncManager *)sharedManager:(NSURLSessionConfiguration*)configuration {
//    static PushSyncManager *_sharedManager = nil;
//    
//    //We only want to create one singleton object, so do that with GCD
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        //Set up the singleton class
//        _sharedManager = [[PushSyncManager alloc] initWithSessionConfiguration:configuration];
//    });
//    
//    return _sharedManager;
//}

- (instancetype)init
{
    
    self = [super initWithBaseURL:self.baseURL];
    if(self) {
        self.torRequests = [NSMutableArray array];
        self.unreachable = true;
        self.startingUp = true;
    }
    
    return self;
}

// Returns the current cached array, and then does another call.
// The caller should show the current array and then handle the call back with new articles
// If the return is nil there is nothing stored and the call will still be made.
- (NSArray*)articlesWithCompletionHandler:(CompletionBlock)completionHandler failure:(FailureBlock)failure;
{

    if(self.unreachable == true){
        [self informCallerThatProxyIsSpinningUpWithType:PushSyncArticles Completion:completionHandler failure:failure requestParameters:nil];
    } else {
        [self GET:@"articles" parameters:@{@"language":[LanguageManager sharedManager].languageShortCode,
                                           @"v":versionNumber, @"categories":@"true"} success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
            
                                               [self handleResponse:responseObject completionHandler:completionHandler];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [self handleError:error failure:failure];
        }];
    }
    
    if(!self.articles || ([self.articles respondsToSelector:@selector(count)] && [self.articles count] == 0) ||
       ([self.articles respondsToSelector:@selector(allKeys)] && [[self.articles allKeys] count] == 0)){
        self.articles = [self getCachedArticles];
    }
    
    return self.articles;
}

- (void)articleWithId:(NSString*)articleId withCompletionHandler:(CompletionBlock)completionHandler failure:(FailureBlock)failure;
{
    NSString * languageShortCode = [LanguageManager sharedManager].languageShortCode;
    
    //iOS uses 'sr' for Serbian, the rest of the world uses 'rs', so switch it here
    if([languageShortCode isEqualToString:@"sr"]){
        languageShortCode = @"rs";
    }
    
    if(self.unreachable == true){
        [self informCallerThatProxyIsSpinningUpWithType:PushSyncArticle Completion:completionHandler failure:failure requestParameters:@{@"article_id": articleId}];
    } else {

        [self GET:@"article" parameters:@{@"id":articleId, @"language":[LanguageManager sharedManager].languageShortCode,
                                         @"v":versionNumber} success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
                                             
                                             [self handleResponse:responseObject completionHandler:completionHandler];
                                             
                                         } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                             [self handleError:error failure:failure];
                                         }];
    }
}

- (void)searchForTerm:(NSString*)searchTerms withCompletionHandler:(CompletionBlock)completionHandler failure:(FailureBlock)failure;
{
    NSString * languageShortCode = [LanguageManager sharedManager].languageShortCode;
    
    //iOS uses 'sr' for Serbian, the rest of the world uses 'rs', so switch it here
    if([languageShortCode isEqualToString:@"sr"]){
        languageShortCode = @"rs";
    }
    
    if(self.unreachable == true){
        [self informCallerThatProxyIsSpinningUpWithType:PushSyncSearch Completion:completionHandler failure:failure requestParameters:@{@"search_terms": searchTerms}];
    } else {
        [self GET:@"search" parameters:@{@"q":searchTerms, @"language":[LanguageManager sharedManager].languageShortCode,
                                         @"v":versionNumber} success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
                                             
                                             [self handleResponse:responseObject completionHandler:completionHandler];
                                             
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [self handleError:error failure:failure];
        }];
    }
}

- (void)handleResponse:(NSDictionary*)responseObject completionHandler:(void(^)(NSObject * articles))completionHandler
{
    NSDictionary * response = (NSDictionary*)responseObject;

    /* we want to handle both categories and consolidated returns */
    
    if(![response.allKeys containsObject:@"categories"]){
        NSArray * articlesResponse = response[@"results"];
        
        NSMutableArray * mutableResponseArray = [NSMutableArray arrayWithCapacity:articlesResponse.count];
        
        for(NSDictionary * articleResponse in articlesResponse){
            Article * article = [Article articleFromDictionary:articleResponse];
            [mutableResponseArray addObject:article];
        }
        
        NSArray * articles = [NSArray arrayWithArray:mutableResponseArray];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(articles);
        });
    } else {
        NSMutableDictionary * mutableCategoriesResponseDictionary = [NSMutableDictionary dictionary];
        NSArray * categoriesArray = response[@"categories"];
        for(NSString * category in categoriesArray){
            NSArray * articles = response[@"results"][category];
            
            NSMutableArray * mutableResponseArray = [NSMutableArray array];
            for(NSDictionary * articleResponse in articles){
                Article * article = [Article articleFromDictionary:articleResponse andCategory:category];
                [mutableResponseArray addObject:article];
            }
            
            mutableCategoriesResponseDictionary[category] = mutableResponseArray;
        }
        
        mutableCategoriesResponseDictionary[@"categories_order"] = categoriesArray;
        
        NSDictionary * categories = [NSDictionary dictionaryWithDictionary:mutableCategoriesResponseDictionary];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(categories);
        });
    }
    
}

- (void)handleError:(NSError*)error failure:(void(^)(NSError *error))failure
{
    [AnalyticsManager logErrorWithErrorDescription:error.localizedDescription];
    dispatch_async(dispatch_get_main_queue(), ^{
        failure(error);
    });
}

// This function uses the "failure" block to let the caller know that a proxy (tor)
// is spinning up in the backend. The completion and failure handlers are held so
// they can be called again. Which ever class is responding to this should use the
// UI to let people know what's going on.
- (void)informCallerThatProxyIsSpinningUpWithType:(PushSyncRequestType)type Completion:(CompletionBlock)completionHandler
                                          failure:(FailureBlock)failureHandler requestParameters:(NSDictionary*)requestParameters
{
    TempRequest * request = [[TempRequest alloc] init];
    request.type = type;
    request.completionHandler = completionHandler;
    request.failureBlock = failureHandler;
    request.requestParameters = requestParameters;
    
    [self.torRequests addObject:request];

    NSError * error = [NSError errorWithDomain:NSNetServicesErrorDomain code:1200 userInfo:nil];
    request.failureBlock(error);
}

- (void)reset
{
    self.articles = nil;
    [self resetCachedArticles];
}

-(NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse * _Nonnull, id _Nullable, NSError * _Nullable))completionHandler
{
    return [super dataTaskWithRequest:request completionHandler:completionHandler];
}

// Pass in either NSArray or NSDictionary
- (void)cacheArticles:(id)articles
{
    NSParameterAssert([articles class] == NSClassFromString(@"NSArray") || [articles class] == NSClassFromString(@"NSDictionary"));
    
    self.articles = articles;
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:articles] forKey:@"cached_articles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


// Returns nill if the key doesn't exist.
- (id)getCachedArticles
{
    NSData * articleData = [[NSUserDefaults standardUserDefaults] objectForKey:@"cached_articles"];
    if(!articleData){
        return nil;
    }
    
    id articles = [NSKeyedUnarchiver unarchiveObjectWithData:articleData];
    
    @try {
        NSParameterAssert([articles class] == NSClassFromString(@"NSArray") || [articles class] == NSClassFromString(@"NSDictionary"));
    } @catch (NSException *exception) {
        return nil;
    }

    return articles;
}

- (void)resetCachedArticles
{
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"cached_articles"];
}

#pragma mark - Private Funcation
#pragma TODO should add compiler checks if tor is illegal or not

- (NSOperationQueue*)operationQueue
{
    if(!_priorityQueue){
        _priorityQueue = [[NSOperationQueue alloc] init];
        _priorityQueue.qualityOfService = NSOperationQualityOfServiceBackground;
    }
    
    return _priorityQueue;
}

- (BOOL)checkInternetReachability
{
    // Check this first
    //+ (instancetype)reachabilityForInternetConnection;

    Reachability *hostReachability = [Reachability reachabilityWithHostName:self.baseHost];
    if(hostReachability.currentReachabilityStatus != NotReachable){
        [self checkIfHostIsBlocked:self.baseHost];
    } else {
        self.unreachable = false;
    }
    
    return true;
}

// Calls base url /heartbeat.json, if it can't reach it, we'll try it on TOR instead
- (void)checkIfHostIsBlocked:(NSString*)host
{
    // We only care if this fails.
    // TODO: Change this to a heartbeat
    self.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    
    [self GET:@"articles" parameters:nil
      progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
          NSLog(@"Host is reachable, not using TOR.");
          self.unreachable = false;
          self.startingUp = false;
      }
      failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
          NSLog(@"Host is not reachable so we're going to start a TOR session.");
          self.startingUp = false;
          //[[TorManager sharedManager] startTorSessionWithSession:self];
          //NSLog(@"%lu", (unsigned long)[TorManager sharedManager].status);
    }];
    
}
//
//- (BOOL)unreachable
//{
//    BOOL ret = nil;
//    @synchronized (self)
//    {
//        if(_unreachable){
//            // I wonder how terrible of an idea this is?
//            while(self.startingUp){
//                [NSThread sleepForTimeInterval:5.0f];
//            }
//        }
//        
//        ret = _unreachable;
//    }
//    
//    return ret;
//}
//
//- (void)setUnreachable:(BOOL)unreachable
//{
//    @synchronized (self) {
//        _unreachable = unreachable;
//    }
//}

#pragma mark - TorSessionDelegate
- (void)didCreateTorSession:(NSURLSession*)session
{
    self.session = session;
    self.unreachable = false;
    self.startingUp = false;

    for(TempRequest * request in self.torRequests){
        switch (request.type) {
            case PushSyncArticles:
                [self articlesWithCompletionHandler:request.completionHandler failure:request.failureBlock];
                break;
            case PushSyncArticle:
                [self articleWithId:request.requestParameters[@"article_id"] withCompletionHandler:request.completionHandler failure:request.failureBlock];
            case PushSyncSearch:
                [self searchForTerm:request.requestParameters[@"search_terms"] withCompletionHandler:request.completionHandler failure:request.failureBlock];
            default:
                break;
        }
    }
    
    [self.torRequests removeAllObjects];
}

- (void)errorCreatingTorSession:(NSError*)error
{
    //Handle TOR creation error here
    self.unreachable = false;
    if(self.torRequests.count > 0){
        TempRequest *request = self.torRequests.firstObject;
        request.failureBlock([NSError errorWithDomain:NSNetServicesErrorDomain code:500 userInfo:@{NSLocalizedDescriptionKey: @"Error proxying your connection. It seems as if our service is blocked."}]);
    }
}

- (NSURL*)baseURL
{
    return [NSURL URLWithString:self.baseHost];
}

- (NSString*)baseHost
{
    return [SettingsManager sharedManager].pushUrl;
}

@end
