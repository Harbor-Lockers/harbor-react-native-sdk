#import "HarborLockersSDK.h"
#import "HarborLockersSDK/HarborLockersSDK-Swift.h"

static NSDictionary<NSString *, NSNumber *> * const RNErrorCodeMap = @{
    @"unknown_error": @(0),
    @"already_in_discovery": @(1),
    @"discovery_timeout": @(2),
    @"invalid_tower_id": @(3)
};

@interface HarborRNErrorUtil : NSObject

+ (void)rejectPromiseWithRNHarborError:(RCTPromiseRejectBlock)reject
                                  code:(NSString *)code
                           description:(NSString *)description;
@end

@implementation HarborRNErrorUtil

+ (void)rejectPromiseWithRNHarborError:(RCTPromiseRejectBlock)reject
                                  code:(NSString *)code
                           description:(NSString *)description
{
  if (!reject) return;
  NSNumber *userInfoCode = RNErrorCodeMap[code] ?: @(0);
  NSString *domain = @"sdk.rn";
  NSDictionary *userInfo = @{
    @"code": userInfoCode,
    @"description": description ?: @"Unknown error",
    @"domain": domain
  };
  NSError *error = [NSError errorWithDomain:domain
                                       code:userInfoCode.intValue
                                   userInfo:userInfo];
  reject(code, description, error);
}
@end

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
- (void)safelyRejectNative:(NSError *)error;
- (void)safelyRejectRN:(NSString *)code description:(NSString *)description;
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

- (void)safelyRejectNative:(NSError *)error {
  [self.lock lock];
  if (self.isActive && self.reject) {
      self.reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
    // Ensure promise is only called once
    self.isActive = NO;
  }
  [self.lock unlock];
}

- (void)safelyRejectRN:(NSString *)code description:(NSString *)description {
  [self.lock lock];
  if (self.isActive && self.reject) {
    [HarborRNErrorUtil rejectPromiseWithRNHarborError:self.reject code:code description:description];
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

@implementation HarborLockersSDK
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
    } else {
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

RCT_EXPORT_METHOD(syncConnectedTower:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
{
    [[HarborSDK shared] syncWithCompletionHandler:^(BOOL success, NSError * _Nullable error) {
        BOOL syncCompleted = success;
        if (error != nil) {
            reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
        } else {
            resolve(@(syncCompleted));
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

RCT_EXPORT_METHOD(connectToTowerWithIdentifier: (nonnull NSString *)towerId
                  resolve:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
{
  [self connectToTowerWithIdentifierAndTimeout:towerId discoveryTimeOut:DISCOVERY_TIME_OUT shouldReturnTowerInfo:NO resolver:resolve rejecter:reject];
}

RCT_EXPORT_METHOD(connectToTower: (nonnull NSString *)towerId
                  discoveryTimeOut: (double)discoveryTimeOut
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  NSNumber * timeOutNumber = @(discoveryTimeOut);
  [self connectToTowerWithIdentifierAndTimeout:towerId discoveryTimeOut:timeOutNumber.integerValue shouldReturnTowerInfo:YES resolver:resolve rejecter:reject];
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
RCT_EXPORT_METHOD(sendRequestSession:(double)role
                  errorCallback: (RCTResponseSenderBlock)errorCallback
                  successCallback: (RCTResponseSenderBlock)successCallback)
{
  [self sendHarborRequestSession:role syncEnabled: YES duration: SESSION_DURATION errorCallback: errorCallback successCallback: successCallback];
}


RCT_EXPORT_METHOD(sendRequestSessionAdvanced: (BOOL)syncEnabled
                  duration: (double)duration
                  role: (double)role
                  errorCallback: (RCTResponseSenderBlock)errorCallback
                  successCallback: (RCTResponseSenderBlock)successCallback)
{
  [self sendHarborRequestSession:role syncEnabled:syncEnabled duration:duration errorCallback:errorCallback successCallback:successCallback];
}

- (void)sendHarborRequestSession:(double)role
                     syncEnabled:(BOOL)syncEnabled
                        duration:(double)duration
                   errorCallback:(RCTResponseSenderBlock)errorCallback
                 successCallback:(RCTResponseSenderBlock)successCallback
{
  SessionPermission permission = (SessionPermission)(long)[@(role) integerValue];
  [[HarborSDK shared] establishSessionWithTowerId:nil
                                         duration: duration
                             automaticSyncEnabled:syncEnabled
                               sessionPermissions:permission
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

RCT_EXPORT_METHOD(sendTerminateSession:(double)errorCode
                  errorMessage:(NSString *)errorMessage
                  resolve:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
{
  NSNumber * errorCodeNumber = @(errorCode);
  [[HarborSDK shared] sendTerminateSessionWithErrorCode:errorCodeNumber.integerValue
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

RCT_EXPORT_METHOD(sendRequestSyncStatusCommand:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
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

RCT_EXPORT_METHOD(sendSyncPullCommand:(double)syncEventStart
                  resolve:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
{
  NSNumber * syncStartNumber = @(syncEventStart);
  [[HarborSDK shared] sendSyncPullWithSyncEventStart:syncStartNumber.unsignedIntValue
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

RCT_EXPORT_METHOD(sendSyncPushCommand:(nonnull NSString *)payload
                  payloadAuth:(nonnull NSString *)payloadAuth
                  resolve:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
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

RCT_EXPORT_METHOD(sendAddClientEventCommand:(nonnull NSString *)clientInfo
                  resolve:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
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

RCT_EXPORT_METHOD(sendFindAvailableLockersCommand:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
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

RCT_EXPORT_METHOD(sendFindLockersWithTokenCommand:(nonnull NSString *)matchToken
                  matchAvailable:(BOOL)matchAvailable
                  resolve:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
{
  NSData * matchTokenData = [[NSData alloc] initWithHexString:matchToken];
    [[HarborSDK shared] sendFindLockersWithTokenWithMatchAvailable:matchAvailable
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

RCT_EXPORT_METHOD(sendOpenLockerWithTokenCommand:(nonnull NSString *)payload
                  payloadAuth:(nonnull NSString *)payloadAuth
                  resolve:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
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

RCT_EXPORT_METHOD(sendOpenAvailableLockerCommand:(nonnull NSString *)lockerToken
                  lockerAvailable:(BOOL)lockerAvailable
                  clientInfo:(nonnull NSString *)clientInfo
                  matchLockerType:(double)matchLockerType
                  matchAvailable:(BOOL)matchAvailable
                  matchToken:(nonnull NSString *)matchToken
                  resolve:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
{
  NSNumber * matchLockerTypeNumber = @(matchLockerType);
  NSData * matchTokenData;
  if(matchToken != nil) {
    matchTokenData = [[NSData alloc] initWithHexString:matchToken];
  }
  NSData * lockerTokenData = [[NSData alloc] initWithHexString:lockerToken];
  NSData * clientInfoData = [[NSData alloc] initWithHexString:clientInfo];

  [[HarborSDK shared] sendOpenAvailableLockerWithMatchLockerType:matchLockerTypeNumber.integerValue
                                                  matchAvailable:matchAvailable
                                                      matchToken:matchTokenData
                                                     lockerToken:lockerTokenData
                                                 lockerAvailable:lockerAvailable
                                                      clientInfo:clientInfoData
                                               completionHandler:^(NSInteger lockerId, NSError * _Nullable error) {
    if (error == nil) {
      resolve(@(lockerId));
    } else {
      reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
    }
  }];
}

RCT_EXPORT_METHOD(sendReopenLockerCommand:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
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

RCT_EXPORT_METHOD(sendRevertLockerStateCommand:(nonnull NSString *)clientInfo
                  resolve:(nonnull RCTPromiseResolveBlock)resolve
                  reject:(nonnull RCTPromiseRejectBlock)reject)
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

RCT_EXPORT_METHOD(sendSetKeypadCodeCommand:(nonnull NSString *)keypadCode
                  keypadCodePersists:(BOOL)keypadCodePersists
                  keypadNextToken:(NSString *)keypadNextToken
                  keypadNextAvailable:(BOOL)keypadNextAvailable
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  NSData * keypadNextTokenData = [[NSData alloc] initWithHexString:keypadNextToken];
  [[HarborSDK shared] sendSetKeypadCodeWithKeypadCode:keypadCode
                                   keypadCodePersists:keypadCodePersists
                                      keypadNextToken:keypadNextTokenData
                                  keypadNextAvailable:keypadNextAvailable
                                    completionHandler:^(BOOL success, NSError * _Nullable error) {
    if (error == nil) {
      resolve(@(success));
    } else {
      reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
    }
  }];
}

RCT_EXPORT_METHOD(sendTapLockerCommand:(double)lockerTapInterval
                  lockerTapCount:(double)lockerTapCount
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  NSNumber * lockerTapIntervalNumber = @(lockerTapInterval);
  NSNumber * lockerTapCountNumber = @(lockerTapCount);
  [[HarborSDK shared] sendTapLockerWithLockerTapIntervalMS:lockerTapIntervalNumber.integerValue
                                            lockerTapCount:lockerTapCountNumber.integerValue
                                         completionHandler:^(BOOL success, NSError * _Nullable error) {
    if (error == nil) {
      resolve(@(success));
    } else {
      reject([NSString stringWithFormat:@"%ld", error.code], error.localizedDescription, error);
    }
  }];
}

// MARK: - HarborSDKDelegate methods -

- (void)harborDidDiscoverTowers:(NSArray<Tower *> * _Nonnull)towers {
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
  NSDictionary * response = @{@"message" : message, @"logType" : [HarborLogLevelName withLevel:logType], @"context" : context,
  };
    if (hasListeners) {
      [self sendEventWithName:@"HarborLogged" body:response];
    }
}

// MARK: - HarborConnectionDelegate methods -

- (void)harborDidDisconnectTower:(Tower *)tower {
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
    [HarborRNErrorUtil rejectPromiseWithRNHarborError:reject code:@"already_in_discovery" description:@"Already discovering towers to connect"];
    return;
  }

  if(![towerId isValidTowerId]) {
    [HarborRNErrorUtil rejectPromiseWithRNHarborError:reject code:@"invalid_tower_id" description:@"Tower Id should be an String with 16 hexadecimal characters"];
    return;
  }

  NSData *towerIdData = [[NSData new] initWithHexString:towerId];
  if (towerIdData == nil) {
    [HarborRNErrorUtil rejectPromiseWithRNHarborError:reject code:@"invalid_tower_id" description:@"Invalid tower id"];
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
        [promiseHandler safelyRejectNative:error];
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

  __weak id weakSelf = self;
  self.dispatchBlock = dispatch_block_create(DISPATCH_BLOCK_DETACHED, ^{
      __strong HarborLockersSDK* strongSelf = weakSelf;
      if (strongSelf) {
        if (strongSelf.dispatchBlock) {
          [strongSelf didFinishDiscoveryToConnect];
        }
        if (promiseHandler) {
          [promiseHandler safelyRejectRN:@"discovery_timeout" description:@"Discovery timeout, tower not found"];
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

#if RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeHarborLockersSDKSpecJSI>(params);
}
#endif

@end
