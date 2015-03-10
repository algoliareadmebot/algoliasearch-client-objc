//
//  Copyright (c) 2013 Algolia
//  http://www.algolia.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "ASAPIClient.h"
#import "ASAPIClient+Network.h"
#import "ASRemoteIndex.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#include <Cocoa/Cocoa.h>
#endif

@implementation ASAPIClient

+(instancetype) apiClientWithApplicationID:(NSString*)applicationID apiKey:(NSString*)apiKey hostnames:(NSArray*)hostnames
{
    return [[ASAPIClient alloc] initWithApplicationID:applicationID apiKey:apiKey hostnames:hostnames dsn:false dsnHost:nil tagFilters:nil userToken:nil];
}

+(instancetype) apiClientWithApplicationID:(NSString*)applicationID apiKey:(NSString*)apiKey
{
    return [[ASAPIClient alloc] initWithApplicationID:applicationID apiKey:apiKey hostnames:nil dsn:false dsnHost:nil tagFilters:nil userToken:nil];
}

-(instancetype) initWithApplicationID:(NSString*)papplicationID apiKey:(NSString*)papiKey hostnames:(NSArray*)phostnames dsn:(Boolean)dsn dsnHost:(NSString*)dsnHost tagFilters:(NSString*)tagFiltersHeader userToken:(NSString*)userTokenHeader
{
    self = [super init];
    if (self) {
        self.applicationID = papplicationID;
        self.apiKey = papiKey;
        self.tagFilters = tagFiltersHeader;
        self.userToken = userTokenHeader;
        self.timeout = 30;
        
        NSMutableArray *array = nil;
        if (phostnames == nil) {
             array = [NSMutableArray arrayWithObjects:
                                     [NSString stringWithFormat:@"%@-1.algolia.net", papplicationID],
                                     [NSString stringWithFormat:@"%@-2.algolia.net", papplicationID],
                                     [NSString stringWithFormat:@"%@-3.algolia.net", papplicationID],
                                     nil];
            srandom((unsigned int)time(NULL));
            NSUInteger count = [array count];
            for (NSUInteger i = 0; i < count; ++i) {
                // Select a random element between i and end of array to swap with.
                NSUInteger nElements = count - i;
                NSUInteger n = (random() % nElements) + i;
                [array exchangeObjectAtIndex:i withObjectAtIndex:n];
            }
            if (dsn || dsnHost != nil) {
                
            }
        } else {
            array = [NSMutableArray arrayWithArray:phostnames];
            srandom((unsigned int)time(NULL));
            NSUInteger count = [array count];
            for (NSUInteger i = 0; i < count; ++i) {
                // Select a random element between i and end of array to swap with.
                NSUInteger nElements = count - i;
                NSUInteger n = (random() % nElements) + i;
                [array exchangeObjectAtIndex:i withObjectAtIndex:n];
            }
            if (dsn || dsnHost != nil) {
                if (dsnHost != nil) {
                    [array insertObject:dsnHost atIndex:0];
                } else {
                    [array insertObject:[NSString stringWithFormat:@"%@-dsn.algolia.net", papplicationID] atIndex:0];
                }
            }
        }
        self.hostnames = array;

        if (self.applicationID == nil || [self.applicationID length] == 0)
            @throw [NSException exceptionWithName:@"InvalidArgument" reason:@"Application ID must be set" userInfo:nil];
        if (self.apiKey == nil || [self.apiKey length] == 0)
            @throw [NSException exceptionWithName:@"InvalidArgument" reason:@"APIKey must be set" userInfo:nil];
        if ([self.hostnames count] == 0)
            @throw [NSException exceptionWithName:@"InvalidArgument" reason:@"List of hosts must be set" userInfo:nil];
        NSMutableArray *httpRequestOperationManagers = [[NSMutableArray alloc] init];
        //NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]; TODO nil
        for (NSString *host in self.hostnames) {
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", host]];
            AFHTTPRequestOperationManager *httpRequestOperationManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:url];
            httpRequestOperationManager.responseSerializer = [AFJSONResponseSerializer serializer];
            httpRequestOperationManager.requestSerializer = [AFJSONRequestSerializer serializer];
            [httpRequestOperationManager.requestSerializer setValue:self.apiKey forHTTPHeaderField:@"X-Algolia-API-Key"];
            [httpRequestOperationManager.requestSerializer setValue:self.applicationID forHTTPHeaderField:@"X-Algolia-Application-Id"];
            [httpRequestOperationManager.requestSerializer setValue:[NSString stringWithFormat:@"Algolia for Objective-C %@", @"3.2.1"] forHTTPHeaderField:@"User-Agent"];
            if (self.tagFilters != nil) {
                [httpRequestOperationManager.requestSerializer setValue:self.tagFilters forHTTPHeaderField:@"X-Algolia-TagFilters"];
            }
            if (self.userToken != nil) {
                [httpRequestOperationManager.requestSerializer setValue:self.userToken forHTTPHeaderField:@"X-Algolia-UserToken"];
            }
            [httpRequestOperationManagers addObject:httpRequestOperationManager];
        }
        operationManagers = httpRequestOperationManagers;
    }
    return self;
}

+(instancetype) apiClientWithDSN:(NSString*)applicationID apiKey:(NSString*)apiKey {
    return [[ASAPIClient alloc] initWithApplicationID:applicationID apiKey:apiKey hostnames:nil dsn:true dsnHost:nil tagFilters:nil userToken:nil];
}

+(instancetype) apiClientWithDSN:(NSString*)applicationID apiKey:(NSString*)apiKey hostnames:(NSArray*)hostnames dsnHost:(NSString*)dsnHost
{
    return [[ASAPIClient alloc] initWithApplicationID:applicationID apiKey:apiKey hostnames:hostnames dsn:true dsnHost:dsnHost tagFilters:nil userToken:nil];
}



-(void) setExtraHeader:(NSString*)value forHeaderField:key
{
    for (AFHTTPRequestOperationManager *manager in operationManagers) {
        [manager.requestSerializer setValue:value forHTTPHeaderField:key];
    }
}

-(void) multipleQueries:(NSArray*)queries
                success:(void(^)(ASAPIClient *client, NSArray *queries, NSDictionary *result))success
                failure: (void(^)(ASAPIClient *client, NSArray *queries, NSString *errorMessage))failure
{
    NSMutableArray *queriesTab =[[NSMutableArray alloc] initWithCapacity:[queries count]];
    int i = 0;
    for (NSDictionary *query in queries) {
        NSString *queryParams = [query[@"query"] buildURL];
        queriesTab[i++] = @{@"params": queryParams, @"indexName": query[@"indexName"]};
    }
    NSString *path = [NSString stringWithFormat:@"/1/indexes/*/queries"];
    NSMutableDictionary *request = [NSMutableDictionary dictionaryWithObject:queriesTab forKey:@"requests"];
    [self performHTTPQuery:path method:@"POST" body:request index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, queries, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, queries, errorMessage);
    }];
}

-(void) listIndexes:(void(^)(ASAPIClient *client, NSDictionary* result))success failure:(void(^)(ASAPIClient *client, NSString *errorMessage))failure
{
    [self performHTTPQuery:@"/1/indexes" method:@"GET" body:nil index:0 timeout:self.timeout success:^(id JSON) {
        success(self, JSON);
    } failure:^(NSString *errorMessage) {
        failure(self, errorMessage);
    }];
}

-(void) moveIndex:(NSString*)srcIndexName to:(NSString*)dstIndexName
          success:(void(^)(ASAPIClient *client, NSString *srcIndexName, NSString *dstIndexName, NSDictionary *result))success
          failure:(void(^)(ASAPIClient *client, NSString *srcIndexName, NSString *dstIndexName, NSString *errorMessage))failure
{
    NSString *path = [NSString stringWithFormat:@"/1/indexes/%@/operation", [ASAPIClient urlEncode:srcIndexName]];
    NSDictionary *request = @{@"destination": dstIndexName, @"operation": @"move"};
    [self performHTTPQuery:path method:@"POST" body:request index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, srcIndexName, dstIndexName, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, srcIndexName, dstIndexName,errorMessage);
    }];
}

-(void) copyIndex:(NSString*)srcIndexName to:(NSString*)dstIndexName
          success:(void(^)(ASAPIClient *client, NSString *srcIndexName, NSString *dstIndexName, NSDictionary *result))success
          failure:(void(^)(ASAPIClient *client, NSString *srcIndexName, NSString *dstIndexName, NSString *errorMessage))failure
{
    NSString *path = [NSString stringWithFormat:@"/1/indexes/%@/operation", [ASAPIClient urlEncode:srcIndexName]];
    NSDictionary *request = @{@"destination": dstIndexName, @"operation": @"copy"};
    [self performHTTPQuery:path method:@"POST" body:request index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, srcIndexName, dstIndexName, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, srcIndexName, dstIndexName,errorMessage);
    }];
}

-(void) getLogs:(void(^)(ASAPIClient *client, NSDictionary *result))success
        failure:(void(^)(ASAPIClient *client, NSString *errorMessage))failure
{
    [self performHTTPQuery:@"/1/logs" method:@"GET" body:nil index:0 timeout:self.timeout success:^(id JSON) {
        success(self, JSON);
    } failure:^(NSString *errorMessage) {
        failure(self, errorMessage);
    }];
}

-(void) getLogsWithOffset:(NSUInteger)offset length:(NSUInteger)length
                  success:(void(^)(ASAPIClient *client, NSUInteger offset, NSUInteger length, NSDictionary *result))success
                  failure:(void(^)(ASAPIClient *client, NSUInteger offset, NSUInteger length, NSString *errorMessage))failure
{
    NSString *url = [NSString stringWithFormat:@"/1/logs?offset=%zd&length=%zd", offset, length];
    [self performHTTPQuery:url method:@"GET" body:nil index:0 timeout:self.timeout success:^(id JSON) {
        success(self, offset, length, JSON);
    } failure:^(NSString *errorMessage) {
        failure(self, offset, length, errorMessage);
    }];
}

-(void) getLogsWithType:(NSUInteger)offset length:(NSUInteger)length type:(NSString*)type
                success:(void(^)(ASAPIClient *client, NSUInteger offset, NSUInteger length, NSString* type, NSDictionary *result))success
                failure:(void(^)(ASAPIClient *client, NSUInteger offset, NSUInteger length, NSString* type, NSString *errorMessage))failure
{
    NSString *url = [NSString stringWithFormat:@"/1/logs?offset=%zd&length=%zd&type=%@", offset, length, type];
    [self performHTTPQuery:url method:@"GET" body:nil index:0 timeout:self.timeout success:^(id JSON) {
        success(self, offset, length, type, JSON);
    } failure:^(NSString *errorMessage) {
        failure(self, offset, length, type, errorMessage);
    }];
}

-(void) deleteIndex:(NSString*)indexName success:(void(^)(ASAPIClient *client, NSString *indexName, NSDictionary *result))success
            failure:(void(^)(ASAPIClient *client, NSString *indexName, NSString *errorMessage))failure
{
    NSString *path = [NSString stringWithFormat:@"/1/indexes/%@", [ASAPIClient urlEncode:indexName]];
    
    [self performHTTPQuery:path method:@"DELETE" body:nil index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, indexName, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, indexName, errorMessage);
    }];
}

-(void) listUserKeys:(void(^)(ASAPIClient *client, NSDictionary* result))success
                     failure:(void(^)(ASAPIClient *client, NSString *errorMessage))failure
{
    [self performHTTPQuery:@"/1/keys" method:@"GET" body:nil index:0 timeout:self.timeout success:^(id JSON) {
        success(self, JSON);
    } failure:^(NSString *errorMessage) {
        failure(self, errorMessage);
    }];
}

-(void) getUserKeyACL:(NSString*)key success:(void(^)(ASAPIClient *client, NSString *key, NSDictionary *result))success
                      failure:(void(^)(ASAPIClient *client, NSString *key, NSString *errorMessage))failure
{
    NSString *path = [NSString stringWithFormat:@"/1/keys/%@", key];
    [self performHTTPQuery:path method:@"GET" body:nil index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, key, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, key, errorMessage);
    }];
}

-(void) deleteUserKey:(NSString*)key success:(void(^)(ASAPIClient *client, NSString *key, NSDictionary *result))success
                       failure:(void(^)(ASAPIClient *client, NSString *key, NSString *errorMessage))failure
{
    NSString *path = [NSString stringWithFormat:@"/1/keys/%@", key];
    [self performHTTPQuery:path method:@"DELETE" body:nil index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, key, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, key, errorMessage);
    }];
}

-(void) addUserKey:(NSArray*)acls success:(void(^)(ASAPIClient *client, NSArray *acls, NSDictionary *result))success
           failure:(void(^)(ASAPIClient *client, NSArray *acls, NSString *errorMessage))failure
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObject:acls forKey:@"acl"];
    [self performHTTPQuery:@"/1/keys" method:@"POST" body:dict index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, acls, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, acls, errorMessage);
    }];
}

-(void) addUserKey:(NSArray*)acls withValidity:(NSUInteger)validity maxQueriesPerIPPerHour:(NSUInteger)maxQueriesPerIPPerHour maxHitsPerQuery:(NSUInteger)maxHitsPerQuery
           success:(void(^)(ASAPIClient *client, NSArray *acls, NSDictionary *result))success
           failure:(void(^)(ASAPIClient *client, NSArray *acls, NSString *errorMessage))failure
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:acls, @"acl", 
                                @(validity), @"validity", 
                                @(maxQueriesPerIPPerHour), @"maxQueriesPerIPPerHour", 
                                @(maxHitsPerQuery), @"maxHitsPerQuery", 
                                nil];
    [self performHTTPQuery:@"/1/keys" method:@"POST" body:dict index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, acls, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, acls, errorMessage);
    }];
}

-(void) addUserKey:(NSArray*)acls withIndexes:(NSArray*)indexes withValidity:(NSUInteger)validity maxQueriesPerIPPerHour:(NSUInteger)maxQueriesPerIPPerHour maxHitsPerQuery:(NSUInteger)maxHitsPerQuery
           success:(void(^)(ASAPIClient *client, NSArray *acls, NSArray *indexes, NSDictionary *result))success
           failure:(void(^)(ASAPIClient *client, NSArray *acls, NSArray *indexes, NSString *errorMessage))failure
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:acls, @"acl", indexes, @"indexes",
                                 @(validity), @"validity",
                                 @(maxQueriesPerIPPerHour), @"maxQueriesPerIPPerHour",
                                 @(maxHitsPerQuery), @"maxHitsPerQuery",
                                 nil];
    [self performHTTPQuery:@"/1/keys" method:@"POST" body:dict index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, acls, indexes, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, acls, indexes, errorMessage);
    }];
}

-(void) updateUserKey:(NSString*)key withACL:(NSArray*)acls success:(void(^)(ASAPIClient *client, NSString *key, NSArray *acls, NSDictionary *result))success
           failure:(void(^)(ASAPIClient *client, NSString *key, NSArray *acls, NSString *errorMessage))failure
{
    NSString *path = [NSString stringWithFormat:@"/1/keys/%@", key];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObject:acls forKey:@"acl"];
    [self performHTTPQuery:path method:@"PUT" body:dict index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, key, acls, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, key, acls, errorMessage);
    }];
}

-(void) updateUserKey:(NSString*)key withACL:(NSArray*)acls withValidity:(NSUInteger)validity maxQueriesPerIPPerHour:(NSUInteger)maxQueriesPerIPPerHour maxHitsPerQuery:(NSUInteger)maxHitsPerQuery
           success:(void(^)(ASAPIClient *client, NSString *key, NSArray *acls, NSDictionary *result))success
           failure:(void(^)(ASAPIClient *client, NSString *key, NSArray *acls, NSString *errorMessage))failure
{
    NSString *path = [NSString stringWithFormat:@"/1/keys/%@", key];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:acls, @"acl",
                                 @(validity), @"validity",
                                 @(maxQueriesPerIPPerHour), @"maxQueriesPerIPPerHour",
                                 @(maxHitsPerQuery), @"maxHitsPerQuery",
                                 nil];
    [self performHTTPQuery:path method:@"PUT" body:dict index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, key, acls, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, key, acls, errorMessage);
    }];
}

-(void) updateUserKey:(NSString*)key withACL:(NSArray*)acls withIndexes:(NSArray*)indexes withValidity:(NSUInteger)validity maxQueriesPerIPPerHour:(NSUInteger)maxQueriesPerIPPerHour maxHitsPerQuery:(NSUInteger)maxHitsPerQuery
           success:(void(^)(ASAPIClient *client, NSString *key, NSArray *acls, NSArray *indexes, NSDictionary *result))success
           failure:(void(^)(ASAPIClient *client, NSString *key, NSArray *acls, NSArray *indexes, NSString *errorMessage))failure
{
    NSString *path = [NSString stringWithFormat:@"/1/keys/%@", key];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:acls, @"acl", indexes, @"indexes",
                                 @(validity), @"validity",
                                 @(maxQueriesPerIPPerHour), @"maxQueriesPerIPPerHour",
                                 @(maxHitsPerQuery), @"maxHitsPerQuery",
                                 nil];
    [self performHTTPQuery:path method:@"PUT" body:dict index:0 timeout:self.timeout success:^(id JSON) {
        if (success != nil)
            success(self, key, acls, indexes, JSON);
    } failure:^(NSString *errorMessage) {
        if (failure != nil)
            failure(self, key, acls, indexes, errorMessage);
    }];
}


-(ASRemoteIndex*) getIndex:(NSString*)indexName
{
    return [ASRemoteIndex remoteIndexWithAPIClient:self indexName:indexName];
}

-(void) setTagFilters:(NSString *)tagFiltersHeader
{
    tagFilters = tagFiltersHeader;
    
    for (AFHTTPRequestOperationManager* manager in self.operationManagers) {
        [manager.requestSerializer setValue:self.tagFilters forHTTPHeaderField:@"X-Algolia-TagFilters"];
    }
}

-(void) setUserToken:(NSString *)userTokenHeader
{
    userToken = userTokenHeader;
    
    for (AFHTTPRequestOperationManager* manager in self.operationManagers) {
        [manager.requestSerializer setValue:self.userToken forHTTPHeaderField:@"X-Algolia-UserToken"];
    }
}

-(void) setApiKey:(NSString *)apiKeyHeader
{
    apiKey = apiKeyHeader;
    
    for (AFHTTPRequestOperationManager* manager in self.operationManagers) {
        [manager.requestSerializer setValue:self.apiKey forHTTPHeaderField:@"X-Algolia-API-Key"];
    }
}

-(void) setApplicationID:(NSString *)applicationIDHeader
{
    applicationID = applicationIDHeader;
    
    for (AFHTTPRequestOperationManager* manager in self.operationManagers) {
        [manager.requestSerializer setValue:self.applicationID forHTTPHeaderField:@"X-Algolia-Application-Id"];
    }
}

@synthesize applicationID;
@synthesize apiKey;
@synthesize hostnames;
@synthesize operationManagers;
@synthesize tagFilters;
@synthesize userToken;
@end
