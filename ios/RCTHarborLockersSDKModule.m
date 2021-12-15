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

@interface RCTHarborLockersSDKModule() <HarborSDKDelegate, HarborSDKConsole>

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
  return @[@"ConsoleOutput", @"TowersFound"];
}

RCT_EXPORT_MODULE(HarborLockersSDK);

// MARK: - SDK Management methods-

RCT_EXPORT_METHOD(initializeSDK)
{
  [[HarborSDK shared] setDelegate:self];
}

RCT_EXPORT_METHOD(startTowersDiscovery) {
  self.foundTowers = [NSMutableDictionary new];
  RCTLog(@"Start devices discovery");
  [[HarborSDK shared] startTowerDiscoveryWithOutputConsole:self];
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

- (void)configureSDKEnvironment:(NSString * _Nullable)environment {
  Environment env = EnvironmentDevelopment;
  if ([[environment lowercaseString] isEqualToString:@"production"]) {
    env = EnvironmentProduction;
  } else if ([environment hasPrefix:@"http://"] || [environment hasPrefix:@"https://"]) {
    [[HarborSDK shared] setBaseURL:environment];
  }
  
  [[HarborSDK shared] setEnvironment:env];
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

// MARK: - Keys Management commands -

RCT_EXPORT_METHOD(sendInstallKeyCommand:(NSNumber * _Nonnull)keyId
                  keyRotation:(NSNumber * _Nonnull)keyRotation
                  keyExpires:(NSNumber * _Nonnull)keyExpires
                  keyData:(NSString * _Nonnull)keyData
                  keyLocator:(NSString * _Nonnull)keyLocator)
{
  [[HarborSDK shared] sendInstallKeyWithKeyId:keyId.integerValue
                               keyRotation:keyRotation.integerValue
                                keyExpires:[NSDate dateWithTimeIntervalSince1970:keyExpires.integerValue]
                                   keyData:[[NSData alloc] initWithHexString:keyData]
                                keyLocator:keyLocator
                         completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSunsetKeyCommand:(NSNumber * _Nonnull)keyId
                  keyRotation:(NSNumber * _Nonnull)keyRotation)
{
  [[HarborSDK shared] sendSunsetKeyWithKeyId:keyId.integerValue
                              keyRotation:keyRotation.integerValue
                        completionHandler:nil];
}

RCT_EXPORT_METHOD(sendRevokeKeyCommand:(NSNumber * _Nonnull)keyId
                  keyRotation:(NSNumber * _Nonnull)keyRotation)
{
  [[HarborSDK shared] sendRevokeKeyWithKeyId:keyId.integerValue
                              keyRotation:keyRotation.integerValue
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
                  payloadAuth:(NSString *)payloadAuth)
{
  NSData * payloadAuthData = [[NSData alloc] initWithHexString:payloadAuth];
  NSData * payloadData = [[NSData alloc] initWithHexString:payload];
  
  [[HarborSDK shared] sendOpenLockerWithTokenWithPayload:payloadData
                                          payloadAuth:payloadAuthData
                                    completionHandler:^(NSInteger lockerId, NSError * _Nullable error) {
    
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

// MARK: - Technician Commands -

RCT_EXPORT_METHOD(sendGetDeviceInfoCommand)
{
  [[HarborSDK shared] sendGetDeviceInfoWithCompletionHandler:^(NSData * _Nonnull towerId,
                                                            NSString * _Nonnull towerName,
                                                            NSString * _Nonnull deviceModel,
                                                            NSString * _Nonnull deviceSerial,
                                                            NSString * _Nonnull towerSerial,
                                                            NSString * _Nonnull firmwareVersion,
                                                            NSInteger mainboardId,
                                                            NSInteger shield1Id,
                                                            NSInteger shield2Id,
                                                            NSInteger solenoidDelay,
                                                            NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendGetKeyInfoCommand:(NSNumber * _Nonnull)keyId
                  keyRotation:(NSNumber * _Nonnull)keyRotation)
{
  [[HarborSDK shared] sendGetKeyInfoWithKeyId:keyId.integerValue
                               keyRotation:keyRotation.integerValue
                         completionHandler:^(BOOL keyValid,
                                             BOOL keySunset,
                                             NSInteger keyExpires,
                                             NSString * _Nonnull keyLocator,
                                             NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendGetLockerInfoCommand:(NSNumber * _Nonnull) lockerId)
{
  [[HarborSDK shared] sendGetLockerInfoWithLockerId:lockerId.integerValue
                               completionHandler:^(NSInteger lockerId,
                                                   NSInteger lockerPhysicalId,
                                                   NSInteger lockerTypeId,
                                                   BOOL lockerAvailable,
                                                   NSData * _Nonnull lockerToken,
                                                   BOOL lockerDisabled,
                                                   NSString * _Nonnull keypadCode,
                                                   NSData * _Nonnull keypadNextToken,
                                                   BOOL keypadNextAvailable,
                                                   BOOL keypadCodePersists,
                                                   NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendReadDeviceStatusCommand)
{
  [[HarborSDK shared] sendReadDeviceStatusWithCompletionHandler:^(NSInteger temperature,
                                                               NSInteger clockTime,
                                                               NSInteger batteryCharge,
                                                               BOOL towerDisabled,
                                                               NSString * _Nonnull towerReason,
                                                               NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendFireLockCommand:(NSNumber * _Nonnull) lockerPhysicalId)
{
  [[HarborSDK shared] sendFireLockWithLockerPhysicalId:lockerPhysicalId.unsignedIntValue
                                  completionHandler:nil];
}

RCT_EXPORT_METHOD(sendControlLightCommand:(NSNumber * _Nonnull) lockerPhysicalId
                  lockerLightOn:(NSNumber * _Nonnull)lockerLightOn)
{
  [[HarborSDK shared] sendControlLightWithLockerPhysicalId:lockerPhysicalId.integerValue
                                          lockerLightOn:lockerLightOn.boolValue
                                      completionHandler:nil];
}

RCT_EXPORT_METHOD(sendReadPortStatusCommand:(NSNumber * _Nonnull) lockerPhysicalId)
{
  [[HarborSDK shared] sendReadPortStatusWithLockerPhysicalId:lockerPhysicalId.unsignedIntValue
                                        completionHandler:^(BOOL lockerLightOn,
                                                            BOOL lockerLockFiring,
                                                            BOOL lockerDoorOpen,
                                                            NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendSoundBuzzerCommand:(NSNumber * _Nonnull) buzzerSound)
{
  [[HarborSDK shared] sendSoundBuzzerWithBuzzerSound:buzzerSound.integerValue
                                completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetClockCommand:(NSNumber * _Nonnull) timestamp)
{
  [[HarborSDK shared] sendSetClockWithTimestamp:timestamp.unsignedIntValue
                           completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetSolenoidDelayCommand:(NSNumber * _Nonnull) solenoidDelay)
{
  [[HarborSDK shared] sendSetSolenoidDelayWithSolenoidDelay:solenoidDelay.integerValue
                                       completionHandler:nil];
}

RCT_EXPORT_METHOD(sendReadKeypadCommand)
{
  [[HarborSDK shared] sendReadKeypadWithCompletionHandler:^(NSInteger keysHeld,
                                                         NSInteger keysPressed,
                                                         NSInteger keysReleased,
                                                         NSError * _Nullable error) {
    
  }];
}

RCT_EXPORT_METHOD(sendSetLockerTokenCommand:(NSNumber * _Nonnull) lockerId
                  lockerToken:(NSString * _Nonnull) lockerToken)
{
  NSData * lockerTokenData = [[NSData alloc] initWithHexString:lockerToken];
  [[HarborSDK shared] sendSetLockerTokenWithLockerId:lockerId.integerValue
                                      lockerToken:lockerTokenData
                                completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetLockerAvailableCommand:(NSNumber * _Nonnull) lockerId
                  lockerAvailable:(NSNumber * _Nonnull) lockerAvailable)
{
  [[HarborSDK shared] sendSetLockerAvailableWithLockerId:lockerId.integerValue
                                      lockerAvailable:lockerAvailable.boolValue
                                    completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetLockerKeypadCommand:(NSNumber * _Nonnull) lockerId
                  keypadCode:(NSString * _Nonnull) keypadCode
                  keypadCodePersists:(NSNumber * _Nonnull) keypadCodePersists
                  keypadNextToken:(NSString * _Nonnull) keypadNextToken
                  keypadNextAvailable:(NSNumber * _Nonnull) keypadNextAvailable)
{
  NSData * keypadNextTokenData = [[NSData alloc] initWithHexString:keypadNextToken];
  [[HarborSDK shared] sendSetLockerKeypadWithLockerId:lockerId.integerValue
                                        keypadCode:keypadCode
                                keypadCodePersists:keypadCodePersists.boolValue
                                   keypadNextToken:keypadNextTokenData
                               keypadNextAvailable:keypadNextAvailable.boolValue
                                 completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetLockerDisabledCommand:(NSNumber * _Nonnull) lockerId
                  lockerDisabled:(NSNumber * _Nonnull) lockerDisabled)
{
  [[HarborSDK shared] sendSetLockerDisabledWithLockerId:lockerId.integerValue
                                      lockerDisabled:lockerDisabled.boolValue
                                   completionHandler:nil];
}

RCT_EXPORT_METHOD(sendReadCounterCommand:(NSNumber * _Nonnull) counterId)
{
  [[HarborSDK shared] sendReadCounterWithCounterId:counterId.integerValue
                              completionHandler:^(NSInteger counterId,
                                                  NSInteger counterValue,
                                                  NSInteger counterLastReset,
                                                  NSError * _Nullable error) {

  }];
}

RCT_EXPORT_METHOD(sendResetCounterCommand:(NSNumber * _Nonnull) counterId)
{
  [[HarborSDK shared] sendResetCounterWithCounterId:counterId.integerValue
                               completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetTowerIdCommand:(NSString *)towerId)
{
  NSData * towerIdData = [[NSData alloc] initWithHexString:towerId];
  [[HarborSDK shared] sendSetTowerIdWithTowerId:towerIdData
                           completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetTowerSerialCommand:(NSString *)towerSerial)
{
  [[HarborSDK shared] sendSetTowerSerialWithTowerSerial:towerSerial
                                   completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetTowerNameCommand:(NSString *)towerName)
{
  [[HarborSDK shared] sendSetTowerNameWithTowerName:towerName
                               completionHandler:nil];
}

RCT_EXPORT_METHOD(sendSetTowerDisabledCommand:(NSNumber * _Nonnull)towerDisabled
                  towerReason:(NSString * _Nonnull)towerReason)
{
  [[HarborSDK shared] sendSetTowerDisabledWithTowerDisabled:towerDisabled.boolValue
                                             towerReason:towerReason
                                       completionHandler:nil];
}

// MARK: - System Commands -

RCT_EXPORT_METHOD(sendResetBatteryGaugeCommand)
{
  [[HarborSDK shared] sendResetBatteryGaugeWithCompletionHandler:nil];
}

RCT_EXPORT_METHOD(sendConfigureLockerCommand:(NSNumber * _Nonnull) lockerId
                  lockerPhysicalId:(NSNumber * _Nonnull) lockerPhysicalId
                  lockerTypeId:(NSNumber * _Nonnull) lockerTypeId)
{
  [[HarborSDK shared] sendConfigureLockerWithLockerId:lockerId.integerValue
                                  lockerPhysicalId:lockerPhysicalId.integerValue
                                      lockerTypeId:lockerTypeId.integerValue
                                 completionHandler:nil];
}

RCT_EXPORT_METHOD(sendAdjustClockCommand:(NSNumber * _Nonnull)clockOffset)
{
  [[HarborSDK shared] sendAdjustClockWithAdjustClock:clockOffset.integerValue
                                completionHandler:nil];
}

RCT_EXPORT_METHOD(sendRebootDeviceCommand)
{
  [[HarborSDK shared] sendRebootDeviceWithCompletionHandler:nil];
}

RCT_EXPORT_METHOD(sendBeginFirmwareUpdateCommand:(NSNumber * _Nonnull)clearAllState
                  fileURL:(NSString *)fileURL)
{
  [[HarborSDK shared] sendBeginFirmwareUpdateWithClearAllState:clearAllState.boolValue
                                                    fileURL:[NSURL URLWithString:fileURL]
                                          completionHandler:nil];
}

RCT_EXPORT_METHOD(sendFactoryResetCommand)
{
  [[HarborSDK shared] sendFactoryResetWithCompletionHandler:nil];
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

// MARK: - HarborSDKConsole methods -

- (void)printToConsole:(NSString * _Nonnull)string {
  if (hasListeners) {
    [self sendEventWithName:@"ConsoleOutput" body:@{@"log": string}];
  }
}

@end
