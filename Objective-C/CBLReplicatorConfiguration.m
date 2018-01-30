//
//  CBLReplicatorConfiguration.m
//  CouchbaseLite
//
//  Created by Pasin Suriyentrakorn on 5/25/17.
//  Copyright © 2017 Couchbase. All rights reserved.
//

#import "CBLReplicatorConfiguration.h"
#import "CBLAuthenticator+Internal.h"
#import "CBLReplicator+Internal.h"
#import "CBLDatabase+Internal.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#import "repo_version.h"    // Generated by get_repo_version.sh at build time

@implementation CBLReplicatorConfiguration {
    BOOL _readonly;
}

@synthesize database=_database, target=_target;
@synthesize replicatorType=_replicatorType, continuous=_continuous;
@synthesize conflictResolver=_conflictResolver;
@synthesize authenticator=_authenticator;
@synthesize pinnedServerCertificate=_pinnedServerCertificate;
@synthesize headers=_headers;
@synthesize documentIDs=_documentIDs, channels=_channels;
@synthesize checkpointInterval=_checkpointInterval, heartbeatInterval=_heartbeatInterval;

- (instancetype) initWithDatabase: (CBLDatabase*)database
                           target: (id<CBLEndpoint>)target
{
    self = [super init];
    if (self) {
        _database = database;
        _target = target;
        _replicatorType = kCBLReplicatorTypePushAndPull;
        _conflictResolver = [[CBLDefaultConflictResolver alloc] init];
    }
    return self;
}


- (instancetype) initWithConfig: (CBLReplicatorConfiguration*)config {
    return [self initWithConfig: config readonly: NO];
}


- (void) setReplicatorType: (CBLReplicatorType)replicatorType {
    [self checkReadonly];
    
    if (_replicatorType != replicatorType) {
        _replicatorType = replicatorType;
    }
}


- (void) setContinuous: (BOOL)continuous {
    [self checkReadonly];
    
    if (_continuous != continuous) {
        _continuous = continuous;
    }
}


- (void) setConflictResolver: (id<CBLConflictResolver>)conflictResolver {
    [self checkReadonly];
    
    if (_conflictResolver != conflictResolver) {
        _conflictResolver = conflictResolver;
    }
}


- (void) setAuthenticator: (CBLAuthenticator *)authenticator {
    [self checkReadonly];
    
    if (_authenticator != authenticator) {
        _authenticator = authenticator;
    }
}


- (void) setPinnedServerCertificate: (SecCertificateRef)pinnedServerCertificate {
    [self checkReadonly];
    
    if (_pinnedServerCertificate != pinnedServerCertificate) {
        _pinnedServerCertificate = pinnedServerCertificate;
    }
}


- (void) setHeaders: (NSDictionary<NSString *,NSString *> *)headers {
    [self checkReadonly];
    
    if (_headers != headers) {
        _headers = headers;
    }
}


- (void) setDocumentIDs: (NSArray<NSString *> *)documentIDs {
    [self checkReadonly];
    
    if (_documentIDs != documentIDs) {
        _documentIDs = documentIDs;
    }
}


- (void) setChannels: (NSArray<NSString *> *)channels {
    [self checkReadonly];
    
    if (_channels != channels) {
        _channels = channels;
    }
}


#pragma mark - Internal


- (instancetype) initWithConfig: (CBLReplicatorConfiguration*)config
                       readonly: (BOOL)readonly {
    self = [super init];
    if (self) {
        _database = config.database;
        _target = config.target;
        _replicatorType = config.replicatorType;
        _continuous = config.continuous;
        _conflictResolver = config.conflictResolver;
        _authenticator = config.authenticator;
        _pinnedServerCertificate = config.pinnedServerCertificate;
        _headers = config.headers;
        _documentIDs = config.documentIDs;
        _channels = config.channels;
        _readonly = readonly;
    }
    return self;
}


- (void) checkReadonly {
    if (_readonly) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"This configuration object is readonly."];
    }
}


- (NSDictionary*) effectiveOptions {
    NSMutableDictionary* options = [NSMutableDictionary dictionary];
    
    // Add authentication info if any:
    [_authenticator authenticate: options];
    
    // Add the pinned certificate if any:
    if (_pinnedServerCertificate) {
        NSData* certData = CFBridgingRelease(SecCertificateCopyData(_pinnedServerCertificate));
        options[@kC4ReplicatorOptionPinnedServerCert] = certData;
    }
    
    // User-Agent and HTTP headers:
    NSMutableDictionary* httpHeaders = [NSMutableDictionary dictionary];
    httpHeaders[@"User-Agent"] = [self.class userAgentHeader];
    if (self.headers)
        [httpHeaders addEntriesFromDictionary: self.headers];
    options[@kC4ReplicatorOptionExtraHeaders] = httpHeaders;
    
    // Filters:
    options[@kC4ReplicatorOptionDocIDs] = _documentIDs;
    options[@kC4ReplicatorOptionChannels] = _channels;
    
    // Checkpoint & heartbeat intervals (no public api now):
    if (_checkpointInterval > 0)
        options[@kC4ReplicatorCheckpointInterval] = @(_checkpointInterval);
    if (_heartbeatInterval > 0)
        options[@kC4ReplicatorHeartbeatInterval] = @(_heartbeatInterval);
    
    return options;
}


+ (NSString*) userAgentHeader {
    static NSString* sUserAgent;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if TARGET_OS_IPHONE
        UIDevice* device = [UIDevice currentDevice];
        NSString* system = [NSString stringWithFormat: @"%@ %@; %@",
                            device.systemName, device.systemVersion, device.model];
#else
        NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
        NSString* version = [NSString stringWithFormat:@"%ld.%ld.%ld",
                             v.majorVersion, v.minorVersion, v.patchVersion];
        NSString* system = [NSString stringWithFormat: @"macOS %@", version];
#endif
        NSString* platform = strcmp(CBL_PRODUCT_NAME, "CouchbaseLiteSwift") == 0 ?
        @"Swift" : @"ObjC";
        
        NSString* commit = strlen(GitCommit) > (0) ?
        [NSString stringWithFormat: @"Commit/%.8s%s", GitCommit, GitDirty] : @"NA";
        
        C4StringResult liteCoreVers = c4_getVersion();
        
        sUserAgent = [NSString stringWithFormat: @"CouchbaseLite/%s (%@; %@) Build/%d %@ LiteCore/%.*s",
                      CBL_VERSION_STRING, platform, system, CBL_BUILD_NUMBER, commit,
                      (int)liteCoreVers.size, liteCoreVers.buf];
        c4slice_free(liteCoreVers);
    });
    return sUserAgent;
}


@end