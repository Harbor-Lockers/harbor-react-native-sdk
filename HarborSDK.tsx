/**
 * This exposes the HarborLockersSDK native module as a JS module.
 */
import { NativeModules } from 'react-native';

const { HarborLockersSDK } = NativeModules;

interface HarborLockersSDKInterface {
  initializeSDK(): void;
  loginWithEmail(
    email: string,
    password: string,
    environment: string
  ): Promise<number>;
  setAccessToken(token: string, environment?: string): void;
  downloadTowerConfigurationWithResolver(): Promise<number>;
  startTowersDiscovery(): void;
  connectToTowerWithIdentifier(
    towerId: string
  ): Promise<HarborLockersSDKInterface>;

  sendRequestSession(
    role: number,
    errorCallback: (errorCode: number, errorMessage: string) => void,
    successCallback: () => void
  ): void;
  sendTerminateSession(errorCode: number, errorMessage?: string): void;
  sendInstallKeyCommand(
    keyId: number,
    keyRotation: number,
    keyExpires: number,
    keyData: string,
    keyLocator: string
  ): void;
  sendSunsetKeyCommand(keyId: number, keyRotation: number): void;
  sendRevokeKeyCommand(keyId: number, keyRotation: number): void;

  sendRequestSyncStatusCommand(): void;
  sendSyncPullCommand(syncEventStart: number): void;
  sendSyncPushCommand(payload: string, payloadAuth: string): void;
  sendMarkSeenEventsCommand(syncEventStart: number): void;
  sendResetEventCounterCommand(syncEventStart: number): void;
  sendResetCommandCounterCommand(syncCommandStart: number): void;
  sendAddClientEventCommand(clientInfo: string): void;

  sendFindAvailableLockersCommand(): void;
  sendFindLockersWithTokenCommand(
    matchToken: string,
    matchAvailable: boolean
  ): void;
  sendOpenLockerWithTokenCommand(
    payload: string,
    payloadAuth: string
  ): Promise<number>;
  sendOpenAvailableLockerCommand(
    lockerToken: string,
    lockerAvailable: boolean,
    clientInfo: string,
    matchLockerType: number,
    matchAvailable: boolean,
    matchToken?: string
  ): void;
  sendReopenLockerCommand(): void;
  sendCheckLockerDoorCommand(callback: (doorOpen: boolean) => void): void;
  sendRevertLockerStateCommand(clientInfo: string): void;
  sendSetKeypadCodeCommand(
    keypadCode: string,
    keypadCodePersists: boolean,
    keypadNextToken: string,
    keypadNextAvailable: boolean
  ): void;
  sendTapLockerCommand(lockerTapInterval: number, lockerTapCount: number): void;
  sendCheckAllLockerDoorsCommand(): void;

  sendGetDeviceInfoCommand(): void;
  sendGetKeyInfoCommand(keyId: number, keyRotation: number): void;
  sendGetLockerInfoCommand(lockerId: number): void;
  sendReadDeviceStatusCommand(): void;
  sendFireLockCommand(lockerPhysicalId: number): void;
  sendControlLightCommand(
    lockerPhysicalId: number,
    lockerLightOn: boolean
  ): void;
  sendReadPortStatusCommand(lockerPhysicalId: number): void;
  sendSoundBuzzerCommand(buzzerSound: number): void;
  sendSetClockCommand(timestamp: number): void;
  sendSetSolenoidDelayCommand(solenoidDelay: number): void;
  sendReadKeypadCommand(): void;
  sendSetLockerTokenCommand(lockerId: number, lockerToken: string): void;
  sendSetLockerAvailableCommand(
    lockerId: number,
    lockerAvailable: boolean
  ): void;
  sendSetLockerKeypadCommand(
    lockerId: number,
    keypadCode: string,
    keypadCodePersists: boolean,
    keypadNextToken: string,
    keypadNextAvailable: boolean
  ): void;
  sendSetLockerDisabledCommand(lockerId: number, lockerDisabled: boolean): void;
  sendReadCounterCommand(counterId: number): void;
  sendResetCounterCommand(counterId: number): void;
  sendSetTowerIdCommand(towerId: string): void;
  sendSetTowerSerialCommand(towerSerial: string): void;
  sendSetTowerNameCommand(towerName: string): void;
  sendSetTowerDisabledCommand(
    towerDisabled: boolean,
    towerReason: string
  ): void;

  sendResetBatteryGaugeCommand(): void;
  sendConfigureLockerCommand(
    lockerId: number,
    lockerPhysicalId: number,
    lockerTypeId: number
  ): void;
  sendAdjustClockCommand(clockOffset: number): void;
  sendRebootDeviceCommand(): void;
  sendBeginFirmwareUpdateCommand(clearAllState: boolean, fileURL: string): void;
  sendFactoryResetCommand(): void;
}

export default HarborLockersSDK as HarborLockersSDKInterface;
