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

@interface RCTHarborLockersSDKModule() <HarborSDKDelegate, HarborLoggerDelegate>

@property (nonatomic, strong) NSMutableDictionary * foundTowers;

@end

@implementation RCTHarborLockersSDKModule
{
  bool hasListeners;
}

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
  return @[@"HarborLogged", @"TowersFound"];
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
  [[HarborSDK shared] setDelegate:self];
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
      resolve(@[@(syncCompleted)]);
    } else if(error != nil) {
      reject([NSString stringWithFormat:@"%ld", error.code], @"Sync connected tower failed", error);
    } else {
      reject(@"sync_error", @"Sync failed", nil);
    }
  }];
}

RCT_EXPORT_METHOD(startTowersDiscovery) {
  self.foundTowers = [NSMutableDictionary new];
  RCTLog(@"Start devices discovery");
  [[HarborSDK shared] startTowerDiscovery];
}

RCT_EXPORT_METHOD(connectToTowerWithIdentifier: (NSString *)towerId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  Tower * towerToConnect = self.foundTowers[towerId];
  if (towerToConnect != nil) {
    [[HarborSDK shared] connectToTower:towerToConnect completion:^(NSString * _Nullable name, NSError * _Nullable error) {
      if([name length] > 0) {
        resolve(@[name]);
      } else if(error != nil) {
        reject([NSString stringWithFormat:@"%ld", error.code], @"Error connecting to a device", error);
      }
    }];
  }
}

// MARK: - API Methods -

RCT_EXPORT_METHOD(loginWithEmail: (NSString *)email
                  password: (NSString *)password
                  environment: (NSString *)environment
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self configureSDKEnvironment:environment];
  [[HarborSDK shared] loginWithEmail:email
                         password:password
                       completion:^(NSInteger responseCode, NSError * _Nullable error) {
    if(responseCode == 200) {
      resolve(@[@(responseCode), @"success"]);
    } else if(error != nil) {
      reject([NSString stringWithFormat:@"%ld", responseCode],
             [NSString stringWithFormat: @"%@\nError loggin in. Response Code: %ld", error.localizedDescription, responseCode],
             error);
    } else {
      reject([NSString stringWithFormat:@"%ld", responseCode],
             [NSString stringWithFormat: @"%@\nError loggin in. Response Code: %ld", @"Unknown Error", responseCode],
             error);
    }
  }];
}

RCT_EXPORT_METHOD(setAccessToken: (NSString *)token
                  environment: (NSString * _Nullable)environment)
{
  if (environment != nil) {
    [self configureSDKEnvironment:environment];
  }
  [[HarborSDK shared] setAccessToken:token];
}

RCT_EXPORT_METHOD(downloadTowerConfigurationWithResolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [[HarborSDK shared] downloadTowerConfigurationWithCompletion:^(BOOL success) {
    if(success) {
      resolve(@[@(YES), @"success"]);
    } else {
      reject([NSString stringWithFormat:@"%@", @(NO)],
             @"\nError downloading tower configuration",
             nil);
    }
  }];
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
  [[HarborSDK shared] establishSessionWithTowerId:nil
                                      duration:600
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

RCT_EXPORT_METHOD(sendTerminateSession:(NSNumber * _Nonnull)errorCode errorMessage:(NSString * _Nullable)errorMessage)
{
  [[HarborSDK shared] sendTerminateSessionWithErrorCode:errorCode.integerValue
                                        errorMessage:errorMessage
                    disconnectAfterSessionTerminated:true
                                   completionHandler:nil];
}

// MARK: - Sync events commands -

RCT_EXPORT_METHOD(sendRequestSyncStatusCommand)
{
  [[HarborSDK shared] sendRequestSyncStatusWithCompletionHandler:^(NSInteger syncEventStart, NSInteger syncEventCount, NSInteger syncCommandStart, NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendSyncPullCommand:(NSNumber * _Nonnull)syncEventStart)
{
  [[HarborSDK shared] sendSyncPullWithSyncEventStart:syncEventStart.unsignedIntValue
                                completionHandler:^(NSInteger firstEventId, NSInteger syncEventCount, NSData * _Nonnull payload, NSData * _Nonnull payloadAuth, NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendSyncPushCommand:(NSString *)payload
                  payloadAuth:(NSString *)payloadAuth)
{
  NSData * payloadData = [[NSData alloc] initWithHexString:payload];
  NSData * payloadAuthData = [[NSData alloc] initWithHexString:payloadAuth];
  [[HarborSDK shared] sendSyncPushWithPayload:payloadData
                               payloadAuth:payloadAuthData
                         completionHandler:nil];
}

RCT_EXPORT_METHOD(sendMarkSeenEventsCommand:(NSNumber * _Nonnull)syncEventStart)
{
  [[HarborSDK shared] sendMarkSeenEventsWithSyncEventStart:syncEventStart.unsignedIntValue
                                      completionHandler:nil];
}

RCT_EXPORT_METHOD(sendResetEventCounterCommand:(NSNumber * _Nonnull)syncEventStart)
{
  [[HarborSDK shared] sendResetEventCounterWithSyncEventStart:syncEventStart.unsignedIntValue
                                         completionHandler:nil];
}

RCT_EXPORT_METHOD(sendResetCommandCounterCommand:(NSNumber * _Nonnull)syncCommandStart)
{
  [[HarborSDK shared] sendResetCommandCounterWithSyncCommandStart:syncCommandStart.unsignedIntValue
                                             completionHandler:nil];
}

RCT_EXPORT_METHOD(sendAddClientEventCommand:(NSString * _Nonnull)clientInfo)
{
  NSData * clientInfoData = [[NSData alloc] initWithHexString:clientInfo];
  [[HarborSDK shared] sendAddClientEventWithClientInfo:clientInfoData
                                  completionHandler:nil];
}

// MARK: - Locker commands -

RCT_EXPORT_METHOD(sendFindAvailableLockersCommand)
{
  [[HarborSDK shared] sendFindAvailableLockersWithCompletionHandler:^(NSDictionary<NSNumber *,NSNumber *> * _Nullable availableLockers, NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendFindLockersWithTokenCommand:(NSString *)matchToken matchAvailable:(NSNumber * _Nonnull)matchAvailable)
{
  NSData * matchTokenData = [[NSData alloc] initWithHexString:matchToken];
  [[HarborSDK shared] sendFindLockersWithTokenWithMatchAvailable:matchAvailable.boolValue
                                                   matchToken:matchTokenData
                                            completionHandler:^(NSDictionary<NSNumber *,NSNumber *> * _Nullable availableLockers, NSError * _Nullable error) {
    
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
      resolve(@[@(lockerId)]);
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
                  matchToken:(NSString * _Nullable)matchToken)
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
    
  }];
}

RCT_EXPORT_METHOD(sendReopenLockerCommand)
{
  [[HarborSDK shared] sendReopenLockerWithCompletionHandler:^(NSInteger lockerId, NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendCheckLockerDoorCommand:(RCTResponseSenderBlock)callback)
{
  [[HarborSDK shared] sendCheckLockerDoorWithCompletionHandler:^(BOOL doorOpen, NSError * _Nullable error) {
    callback(@[@(doorOpen)]);
  }];
}

RCT_EXPORT_METHOD(sendRevertLockerStateCommand:(NSString * _Nonnull)clientInfo)
{
  NSData * clientInfoData = [[NSData alloc] initWithHexString:clientInfo];
  [[HarborSDK shared] sendRevertLockerStateWithClientInfo:clientInfoData
                                     completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetKeypadCodeCommand:(NSString * _Nonnull)keypadCode
                  keypadCodePersists:(NSNumber * _Nonnull)keypadCodePersists
                  keypadNexttoken:(NSString * _Nonnull)keypadNextToken
                  keypadNextAvailable:(NSNumber * _Nonnull)keypadNextAvailable)
{
  NSData * keypadNextTokenData = [[NSData alloc] initWithHexString:keypadNextToken];
  [[HarborSDK shared] sendSetKeypadCodeWithKeypadCode:keypadCode
                                keypadCodePersists:keypadCodePersists.boolValue
                                   keypadNextToken:keypadNextTokenData
                               keypadNextAvailable:keypadNextAvailable.boolValue
                                 completionHandler:nil];
}

RCT_EXPORT_METHOD(sendTapLockerCommand:(NSNumber * _Nonnull)lockerTapInterval
                  lockerTapCount:(NSNumber * _Nonnull)lockerTapCount)
{
  [[HarborSDK shared] sendTapLockerWithLockerTapIntervalMS:lockerTapInterval.integerValue
                                         lockerTapCount:lockerTapCount.integerValue
                                      completionHandler:nil];
}

RCT_EXPORT_METHOD(sendCheckAllLockerDoorsCommand)
{
  [[HarborSDK shared] sendCheckAllLockerDoorsWithCompletionHandler:^(NSData * _Nullable lockerDoorStates, NSError * _Nullable error) {
    
  }];
}


// MARK: - HarborSDKDelegate methods -

- (void)harborDidDiscoverTowers:(NSArray<Tower *> *)towers {
  NSMutableArray * towersInfo = [NSMutableArray new];
  for(Tower * tower in towers) {
    self.foundTowers[[[tower towerId] hexString]] = tower;
    NSDictionary * towerInfo = @{@"towerId" : [[tower towerId] hexString],
                                 @"towerName" : [tower towerName],
    };
    [towersInfo addObject:towerInfo];
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

@end
