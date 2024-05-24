//
//  RCTHarborLockersSDKModule.m
//  LALApp
//
//  Created by Lucas on 3/29/21.
//

#import <React/RCTLog.h>
#import <React/RCTConvert.h>
#import "RCTHarborLockersSDKModule.h"
#import <HarborLockersSDK/HarborLockersSDK.h>
#import <HarborLockersSDK/HarborLockersSDK-Swift.h>

@interface NSString (HexValidation)
- (BOOL)isValidHexNumber;
- (BOOL)isValidTowerId;
@end

@implementation NSString (HexValidation)
- (BOOL)isValidTowerId {
  if ([self length] != 16) {
      return NO;
  }
    return [self isValidHexNumber];
}

- (BOOL)isValidHexNumber {
    if ([self isEqualToString:@""]) {
        return NO;
    }
    
    NSCharacterSet *chars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] invertedSet];
    NSRange range = [self.uppercaseString rangeOfCharacterFromSet:chars];
    return (range.location == NSNotFound);
}
@end

@interface PromiseHandler : NSObject

@property (nonatomic, copy) RCTPromiseResolveBlock resolve;
@property (nonatomic, copy) RCTPromiseRejectBlock reject;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL isActive;

- (instancetype)initWithResolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;
- (void)safelyRejectWithCode:(NSString *)code reason:(NSString *)reason error:(NSError *)error;
- (void)safelyResolve:(id)response;

@end

@implementation PromiseHandler

- (instancetype)initWithResolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _isActive = YES;
        _resolve = [resolve copy];
        _reject = [reject copy];
    }
    return self;
}

- (void)safelyRejectWithCode:(NSString *)code reason:(NSString *)reason error:(NSError *)error {
    [self.lock lock];
    if (self.isActive && self.reject) {
        self.reject(code, reason, error);
        // Ensure promise is only called once
        self.isActive = NO;
    }
    [self.lock unlock];
}

- (void)safelyResolve:(id)response {
    [self.lock lock];
    if (self.isActive && self.resolve) {
        self.resolve(response);
        // Ensure promise is only called once
        self.isActive = NO;
    }
    [self.lock unlock];
}
@end


@interface RCTHarborLockersSDKModule() <HarborSDKDelegate, HarborLoggerDelegate, HarborConnectionDelegate>

@property (nonatomic, strong) NSMutableDictionary * foundTowers;
@property (nonatomic, strong) NSMutableDictionary * cachedTowers;
@property (nonatomic, copy) dispatch_block_t dispatchBlock;

@end

@implementation RCTHarborLockersSDKModule
{
  bool hasListeners;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _foundTowers = [NSMutableDictionary new];
        _cachedTowers = [NSMutableDictionary new];
    }
    return self;
}

const int SESSION_DURATION = 60*60*1;
const int DISCOVERY_TIME_OUT = 20;
PromiseHandler *promiseHandler = nil;
NSData * towerIdDiscovering;
BOOL isDiscoveringToConnect = NO;
BOOL returnTowerInfoInConnection = NO;

// Will be called when this module's first listener is added.
-(void)startObserving {
  hasListeners = YES;
}

// Will be called when this module's last listener is removed, or on dealloc.
-(void)stopObserving {
  hasListeners = NO;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"HarborLogged", @"TowersFound", @"TowerDisconnected"];
}


RCT_EXPORT_MODULE(HarborLockersSDK);

// MARK: - Helper methods -
- (HarborLogLevel)logLevelFromString:(NSString * _Nonnull)logLevel {
    if (logLevel == nil) return HarborLogLevelInfo;

    if ([logLevel caseInsensitiveCompare:[HarborLogLevelName withLevel:HarborLogLevelDebug]] == NSOrderedSame) {
        return HarborLogLevelDebug;
    } else if ([logLevel caseInsensitiveCompare:[HarborLogLevelName withLevel:HarborLogLevelVerbose]] == NSOrderedSame) {
        return HarborLogLevelVerbose;
    } else if ([logLevel caseInsensitiveCompare:[HarborLogLevelName withLevel:HarborLogLevelWarning]] == NSOrderedSame) {
        return HarborLogLevelWarning;
    } else if ([logLevel caseInsensitiveCompare:[HarborLogLevelName withLevel:HarborLogLevelError]] == NSOrderedSame) {
        return HarborLogLevelError;
    }else{
        return HarborLogLevelInfo;
    }
}

// MARK: - SDK Management methods-

RCT_EXPORT_METHOD(initializeSDK)
{
  self.foundTowers = [NSMutableDictionary new];
  [[HarborSDK shared] setDelegate:self];
  [[HarborSDK shared] setConnectionDelegate:self];
}

RCT_EXPORT_METHOD(setLogLevel:(NSString *)logLevel)
{
  [HarborSDK shared].logLevel = [self logLevelFromString:logLevel];
  [HarborSDK shared].loggerDelegate = self;
}


RCT_EXPORT_METHOD(isSyncing: (RCTResponseSenderBlock)callback)
{
  BOOL isSyncing = [[HarborSDK shared] isSyncing];
  callback(@[@(isSyncing)]);
}

RCT_EXPORT_METHOD(syncConnectedTower:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [[HarborSDK shared] syncWithCompletionHandler:^(BOOL success, NSError * _Nullable error) {
    BOOL syncCompleted = success;
    if(syncCompleted) {
      resolve(@(syncCompleted));
    } else if(error != nil) {
      reject([NSString stringWithFormat:@"%ld", error.code], @"Sync connected tower failed", error);
    } else {
      reject(@"sync_error", @"Sync failed", nil);
    }
  }];
}

RCT_EXPORT_METHOD(startTowersDiscovery) {
  if (isDiscoveringToConnect) {
    return;
  }
  self.foundTowers = [NSMutableDictionary new];
  [[HarborSDK shared] startTowerDiscovery];
}

RCT_EXPORT_METHOD(connectToTowerWithIdentifier: (NSString *)towerId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self connectToTowerWithIdentifierAndTimeout:towerId discoveryTimeOut:DISCOVERY_TIME_OUT shouldReturnTowerInfo:NO resolver:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(connectToTower: (NSString *)towerId
                  discoveryTimeOut: (NSInteger)timeOut
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self connectToTowerWithIdentifierAndTimeout:towerId discoveryTimeOut:timeOut shouldReturnTowerInfo:YES resolver:resolve rejecter:reject];
}

// MARK: - API Methods -

RCT_EXPORT_METHOD(setAccessToken: (NSString *)token
                  environment: (NSString * _Nullable)environment)
{
  if (environment != nil) {
    [self configureSDKEnvironment:environment];
  }
  [[HarborSDK shared] setAccessToken:token];
}

- (void)configureSDKEnvironment:(NSString * _Nullable)environment
{
  if ([environment hasPrefix:@"http://"] || [environment hasPrefix:@"https://"]) {
    [[HarborSDK shared] setBaseURL:environment];
  } else {
    Environment env = EnvironmentDevelopment;
    if ([[environment lowercaseString] isEqualToString:@"production"]) {
      env = EnvironmentProduction;
    } else if ([[environment lowercaseString] isEqualToString:@"sandbox"]) {
      env = EnvironmentSandbox;
    }
    [[HarborSDK shared] setEnvironment:env];
  }
}

// MARK: - Session Commands -

RCT_EXPORT_METHOD(sendRequestSession:(NSNumber * _Nonnull)role
                  errorCallback: (RCTResponseSenderBlock)errorCallback
                  successCallback: (RCTResponseSenderBlock)successCallback)
{
    [self sendHarborRequestSession: role syncEnabled: YES duration: SESSION_DURATION errorCallback: errorCallback successCallback: successCallback];
}

RCT_EXPORT_METHOD(sendRequestSessionAdvanced: (NSNumber * _Nonnull)syncEnabled
                  duration: (NSInteger)duration
                  role: (NSNumber * _Nonnull)role
                  errorCallback: (RCTResponseSenderBlock)errorCallback
                  successCallback: (RCTResponseSenderBlock)successCallback)
{
    [self sendHarborRequestSession: role syncEnabled: syncEnabled.boolValue duration: duration errorCallback: errorCallback successCallback: successCallback];
}

RCT_EXPORT_METHOD(sendHarborRequestSession:(NSNumber * _Nonnull)role
                  syncEnabled:(BOOL)syncEnabled
                  duration: (NSInteger)duration
                  errorCallback: (RCTResponseSenderBlock)errorCallback
                  successCallback: (RCTResponseSenderBlock)successCallback)
{
  [[HarborSDK shared] establishSessionWithTowerId:nil
                                      duration: duration
                                      automaticSyncEnabled:syncEnabled
                            sessionPermissions:role.integerValue
                             completionHandler:^(BOOL success,
                                                 NSError * _Nullable error) {
    if(!success) {
      if (error != nil) {
        errorCallback(@[@(error.code), error.localizedDescription]);
      } else {
        errorCallback(@[@(0), @"Unknown error establishing session"]);
      }
    } else {
      successCallback(@[]);
    }
  }];
}

RCT_EXPORT_METHOD(sendTerminateSession:(NSNumber * _Nonnull)errorCode 
                  errorMessage:(NSString * _Nullable)errorMessage
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [[HarborSDK shared] sendTerminateSessionWithErrorCode:errorCode.integerValue
                                           errorMessage:errorMessage
                       disconnectAfterSessionTerminated:true
                                      completionHandler:^(BOOL success, NSError * _Nullable error) {
      if (error == nil) {
        resolve(@(success));
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

// MARK: - Sync events commands -

RCT_EXPORT_METHOD(sendRequestSyncStatusCommand:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [[HarborSDK shared] sendRequestSyncStatusWithCompletionHandler:^(NSInteger syncEventStart, NSInteger syncEventCount, NSInteger syncCommandStart, NSError * _Nullable error) {
      if (error == nil) {
        NSDictionary * syncResponse = @{@"syncEventStart" : @(syncEventStart),
                                        @"syncEventCount" : @(syncEventCount),
                                        @"syncCommandStart" : @(syncCommandStart)};
        resolve(syncResponse);
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

RCT_EXPORT_METHOD(sendSyncPullCommand:(NSNumber * _Nonnull)syncEventStart
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [[HarborSDK shared] sendSyncPullWithSyncEventStart:syncEventStart.unsignedIntValue
                                completionHandler:^(NSInteger firstEventId, NSInteger syncEventCount, NSData * _Nonnull payload, NSData * _Nonnull payloadAuth, NSError * _Nullable error) {
      if (error == nil) {
        NSDictionary * syncResponse = @{@"firstEventId" : @(firstEventId),
                                          @"syncEventCount" : @(syncEventCount),
                                          @"payload" : [payload hexString],
                                          @"payloadAuth" : [payloadAuth hexString]};
        resolve(syncResponse);
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

RCT_EXPORT_METHOD(sendSyncPushCommand:(NSString *)payload
                  payloadAuth:(NSString *)payloadAuth
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSData * payloadData = [[NSData alloc] initWithHexString:payload];
  NSData * payloadAuthData = [[NSData alloc] initWithHexString:payloadAuth];
  [[HarborSDK shared] sendSyncPushWithPayload:payloadData
                               payloadAuth:payloadAuthData
                            completionHandler:^(BOOL success, NSError * _Nullable error) {
      if (error == nil) {
        resolve(@(success));
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

RCT_EXPORT_METHOD(sendAddClientEventCommand:(NSString * _Nonnull)clientInfo
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSData * clientInfoData = [[NSData alloc] initWithHexString:clientInfo];
  [[HarborSDK shared] sendAddClientEventWithClientInfo:clientInfoData
                                     completionHandler:^(BOOL success, NSError * _Nullable error) {
      if (error == nil) {
        resolve(@(success));
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

// MARK: - Locker commands -

RCT_EXPORT_METHOD(sendFindAvailableLockersCommand:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [[HarborSDK shared] sendFindAvailableLockersWithCompletionHandler:^(NSDictionary<NSNumber *,NSNumber *> * _Nullable availableLockers, NSError * _Nullable error) {
      if (error == nil) {
        if (availableLockers == nil) {
          resolve(@{});
        } else {
          resolve(availableLockers);
        }
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

RCT_EXPORT_METHOD(sendFindLockersWithTokenCommand:(NSString *)matchToken 
                  matchAvailable:(NSNumber * _Nonnull)matchAvailable
                  resolver: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSData * matchTokenData = [[NSData alloc] initWithHexString:matchToken];
  [[HarborSDK shared] sendFindLockersWithTokenWithMatchAvailable:matchAvailable.boolValue
                                                   matchToken:matchTokenData
                                            completionHandler:^(NSDictionary<NSNumber *,NSNumber *> * _Nullable availableLockers, NSError * _Nullable error) {
      if (error == nil) {
        if (availableLockers == nil) {
          resolve(@{});
        } else {
          resolve(availableLockers);
        }
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

RCT_EXPORT_METHOD(sendOpenLockerWithTokenCommand:(NSString *)payload
                  payloadAuth:(NSString *)payloadAuth
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSData * payloadAuthData = [[NSData alloc] initWithHexString:payloadAuth];
  NSData * payloadData = [[NSData alloc] initWithHexString:payload];
  
  [[HarborSDK shared] sendOpenLockerWithTokenWithPayload:payloadData
                                          payloadAuth:payloadAuthData
                                    completionHandler:^(NSInteger lockerId, NSError * _Nullable error) {
    if (error == nil) {
      resolve(@(lockerId));
    } else {
      reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
    }
  }];
}

RCT_EXPORT_METHOD(sendOpenAvailableLockerCommand:(NSString * _Nonnull)lockerToken
                  lockerAvailable:(NSNumber * _Nonnull)lockerAvailable
                  clientInfo:(NSString * _Nonnull)clientInfo
                  matchLockerType:(NSNumber * _Nonnull)matchLockerType
                  matchAvailable:(NSNumber * _Nonnull) matchAvailable
                  matchToken:(NSString * _Nullable)matchToken
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSData * matchTokenData;
  if(matchToken != nil) {
    matchTokenData = [[NSData alloc] initWithHexString:matchToken];
  }
  NSData * lockerTokenData = [[NSData alloc] initWithHexString:lockerToken];
  NSData * clientInfoData = [[NSData alloc] initWithHexString:clientInfo];
  
  [[HarborSDK shared] sendOpenAvailableLockerWithMatchLockerType:matchLockerType.integerValue
                                               matchAvailable:matchAvailable.boolValue
                                                   matchToken:matchTokenData
                                                  lockerToken:lockerTokenData
                                              lockerAvailable:lockerAvailable.boolValue
                                                   clientInfo:clientInfoData
                                            completionHandler:^(NSInteger lockerId, NSError * _Nullable error) {
      if (error == nil) {
        resolve(@(lockerId));
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

RCT_EXPORT_METHOD(sendReopenLockerCommand:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [[HarborSDK shared] sendReopenLockerWithCompletionHandler:^(NSInteger lockerId, NSError * _Nullable error) {
      if (error == nil) {
        resolve(@(lockerId));
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

RCT_EXPORT_METHOD(sendCheckLockerDoorCommand:(RCTResponseSenderBlock)callback)
{
  [[HarborSDK shared] sendCheckLockerDoorWithCompletionHandler:^(BOOL doorOpen, NSError * _Nullable error) {
    callback(@[@(doorOpen)]);
  }];
}

RCT_EXPORT_METHOD(sendRevertLockerStateCommand:(NSString * _Nonnull)clientInfo
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSData * clientInfoData = [[NSData alloc] initWithHexString:clientInfo];
  [[HarborSDK shared] sendRevertLockerStateWithClientInfo:clientInfoData
                                        completionHandler:^(BOOL success, NSError * _Nullable error) {
      if (error == nil) {
        resolve(@(success));
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

RCT_EXPORT_METHOD(sendSetKeypadCodeCommand:(NSString * _Nonnull)keypadCode
                  keypadCodePersists:(NSNumber * _Nonnull)keypadCodePersists
                  keypadNexttoken:(NSString * _Nonnull)keypadNextToken
                  keypadNextAvailable:(NSNumber * _Nonnull)keypadNextAvailable
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSData * keypadNextTokenData = [[NSData alloc] initWithHexString:keypadNextToken];
  [[HarborSDK shared] sendSetKeypadCodeWithKeypadCode:keypadCode
                                keypadCodePersists:keypadCodePersists.boolValue
                                   keypadNextToken:keypadNextTokenData
                               keypadNextAvailable:keypadNextAvailable.boolValue
                                    completionHandler:^(BOOL success, NSError * _Nullable error) {
      if (error == nil) {
        resolve(@(success));
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

RCT_EXPORT_METHOD(sendTapLockerCommand:(NSNumber * _Nonnull)lockerTapInterval
                  lockerTapCount:(NSNumber * _Nonnull)lockerTapCount
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [[HarborSDK shared] sendTapLockerWithLockerTapIntervalMS:lockerTapInterval.integerValue
                                         lockerTapCount:lockerTapCount.integerValue
                                         completionHandler:^(BOOL success, NSError * _Nullable error) {
      if (error == nil) {
        resolve(@(success));
      } else {
        reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
      }
  }];
}

// MARK: - HarborSDKDelegate methods -

- (void)harborDidDiscoverTowers:(NSArray<Tower *> *)towers {
  NSMutableArray * towersInfo = [NSMutableArray new];
  for(Tower * tower in towers) {
    self.foundTowers[tower.towerId] = tower;
    self.cachedTowers[tower.towerId] = tower;
    if (hasListeners) {
      NSDictionary * towerInfo = @{@"towerId" : [[tower towerId] hexString],
                                   @"towerName" : [tower towerName],
                                   @"firmwareVersion" : [tower firmwareVersion],
                                   @"rssi" : [tower RSSI],
      };
      [towersInfo addObject:towerInfo];
    }

    if (isDiscoveringToConnect && [tower.towerId isEqualToData: towerIdDiscovering]) {
      [self didFinishDiscoveryToConnect];
      [self connectToHarborTower:tower];
    }
  }
  if (hasListeners) {
    [self sendEventWithName:@"TowersFound" body:towersInfo];
  }
}


// MARK: - HarborLoggerDelegate methods -

- (void)harborDidLogWithMessage:(NSString * _Nonnull)message logType:(enum HarborLogLevel)logType context:(NSDictionary<NSString *,id> * _Nullable)context {
    NSDictionary * response = @{@"message" : message,
                                @"logType" : [HarborLogLevelName withLevel:logType],
                                @"context" : context,
    };
    if (hasListeners) {
      [self sendEventWithName:@"HarborLogged" body:response];
    }
}

// MARK: - HarborConnectionDelegate methods -

- (void)harborDidDisconnectTower:(Tower*)tower {
  if (hasListeners) {
    NSDictionary * towerInfo = @{@"towerId" : [[tower towerId] hexString],
                                 @"towerName" : [tower towerName],
                                 @"firmwareVersion" : [tower firmwareVersion],
                                 @"rssi" : [tower RSSI],
    };
    [self sendEventWithName:@"TowerDisconnected" body:towerInfo];
  }
}


// MARK: - Connect to tower - helpers -

-(void) connectToTowerWithIdentifierAndTimeout: (NSString *)towerId
                  discoveryTimeOut: (NSInteger)timeOut
                  shouldReturnTowerInfo:(BOOL)returnTowerInfo
                  resolver: (RCTPromiseResolveBlock)resolve
                  rejecter: (RCTPromiseRejectBlock)reject
{
  if (isDiscoveringToConnect) {
    reject(@"already_in_discovery", @"Already discovering towers to connect", nil);
  }

  if(![towerId isValidTowerId]) {
    reject(@"invalid_tower_id", @"Tower Id should be an String with 16 hexadecimal characters", nil);
    return;
  }

  NSData *towerIdData = [[NSData new] initWithHexString:towerId];
  if (towerIdData == nil) {
    reject(@"invalid_tower_id", @"Invalid tower id", nil);
    return;
  }

  returnTowerInfoInConnection = returnTowerInfo;
  promiseHandler = [[PromiseHandler alloc] initWithResolve:resolve reject:reject];

  Tower* towerToConnect = self.cachedTowers[towerIdData];
  if (towerToConnect) {
    [self connectToHarborTower:towerToConnect];
    return;
  }

  [self discoverAndConnect:towerIdData discoveryTimeOut:timeOut];
}

-(void) connectToHarborTower: (Tower *)towerToConnect
{
  [[HarborSDK shared] connectToTower:towerToConnect completion:^(NSString * _Nullable name, NSError * _Nullable error) {
    if(promiseHandler) {
      if([name length] > 0) {
        if(returnTowerInfoInConnection) {
          NSDictionary * towerInfo = @{@"towerId" : [[towerToConnect towerId] hexString],
                                       @"towerName" : [towerToConnect towerName],
                                       @"firmwareVersion" : [towerToConnect firmwareVersion],
                                       @"rssi" : [towerToConnect RSSI]};
          [promiseHandler safelyResolve:towerInfo];
        } else {
          [promiseHandler safelyResolve:name];
        }
      } else if(error != nil) {
        [promiseHandler safelyRejectWithCode:[NSString stringWithFormat:@"%ld", error.code] reason:@"Error connecting to a device" error:error];
      }
    }
  }];
}

-(void) discoverAndConnect: (NSData *) towerIdData
                  discoveryTimeOut: (NSInteger)timeOut
{
  isDiscoveringToConnect = YES;
  towerIdDiscovering = towerIdData;
  [[HarborSDK shared] startTowerDiscovery];

  __weak typeof(self) weakSelf = self;
  self.dispatchBlock = dispatch_block_create(DISPATCH_BLOCK_DETACHED, ^{
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (strongSelf) {
        if (strongSelf.dispatchBlock) {
          [strongSelf didFinishDiscoveryToConnect];
        }
        if (promiseHandler) {
          [promiseHandler safelyRejectWithCode:@"discovery_timeout" reason:@"Discovery timeout, tower not found" error:nil];
        }
      }
  });

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeOut * NSEC_PER_SEC)), dispatch_get_main_queue(), self.dispatchBlock);
}

-(void) didFinishDiscoveryToConnect
{
  if (self.dispatchBlock) {
    dispatch_block_cancel(self.dispatchBlock);
  }
  isDiscoveringToConnect = NO;
  towerIdDiscovering = nil;
}

@end
