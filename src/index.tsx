import type {
  LockerTypesAvailability,
  SyncEvents,
  SyncStatus,
  Tower,
} from './HarborTypes';
import NativeHarborLockersSDK from './NativeHarborLockersSDK';
export { DEFAULT_TOWER_ID } from './NativeHarborLockersSDK';
export { HarborError } from './HarborError';

class HarborLockersSDK {
  static initializeSDK = (): void => {
    NativeHarborLockersSDK.initializeSDK();
  };

  static setLogLevel = (logLevel: string): void => {
    NativeHarborLockersSDK.setLogLevel(logLevel);
  };

  static isSyncing = (callback: (isSyncing: boolean) => void): void => {
    NativeHarborLockersSDK.isSyncing(callback);
  };

  static syncConnectedTower = (): Promise<boolean> => {
    return NativeHarborLockersSDK.syncConnectedTower();
  };

  static setAccessToken = (token: string, environment?: string): void => {
    NativeHarborLockersSDK.setAccessToken(token, environment);
  };

  static startTowersDiscovery = (): void => {
    NativeHarborLockersSDK.startTowersDiscovery();
  };

  static connectToTowerWithIdentifier = (towerId: string): Promise<string> => {
    return NativeHarborLockersSDK.connectToTowerWithIdentifier(towerId);
  };

  static connectToTower = (
    towerId: string,
    discoveryTimeOut: number
  ): Promise<Tower> => {
    return NativeHarborLockersSDK.connectToTower(towerId, discoveryTimeOut);
  };

  static sendRequestSession = (
    role: number,
    errorCallback: (errorCode: number, errorMessage: string) => void,
    successCallback: () => void
  ): void => {
    NativeHarborLockersSDK.sendRequestSession(
      role,
      errorCallback,
      successCallback
    );
  };

  static sendRequestSessionAdvanced = (
    syncEnabled: boolean,
    duration: number,
    role: number,
    errorCallback: (errorCode: number, errorMessage: string) => void,
    successCallback: () => void
  ): void => {
    NativeHarborLockersSDK.sendRequestSessionAdvanced(
      syncEnabled,
      duration,
      role,
      errorCallback,
      successCallback
    );
  };

  static sendTerminateSession = (
    errorCode: number,
    errorMessage?: string
  ): Promise<boolean> => {
    return NativeHarborLockersSDK.sendTerminateSession(errorCode, errorMessage);
  };

  static sendRequestSyncStatusCommand = (): Promise<SyncStatus> => {
    return NativeHarborLockersSDK.sendRequestSyncStatusCommand();
  };

  static sendSyncPullCommand = (
    syncEventStart: number
  ): Promise<SyncEvents> => {
    return NativeHarborLockersSDK.sendSyncPullCommand(syncEventStart);
  };

  static sendSyncPushCommand = (
    payload: string,
    payloadAuth: string
  ): Promise<boolean> => {
    return NativeHarborLockersSDK.sendSyncPushCommand(payload, payloadAuth);
  };

  static sendAddClientEventCommand = (clientInfo: string): Promise<boolean> => {
    return NativeHarborLockersSDK.sendAddClientEventCommand(clientInfo);
  };

  static sendFindAvailableLockersCommand =
    (): Promise<LockerTypesAvailability> => {
      return NativeHarborLockersSDK.sendFindAvailableLockersCommand();
    };

  static sendFindLockersWithTokenCommand = (
    matchToken: string,
    matchAvailable: boolean
  ): Promise<LockerTypesAvailability> => {
    return NativeHarborLockersSDK.sendFindLockersWithTokenCommand(
      matchToken,
      matchAvailable
    );
  };

  static sendOpenLockerWithTokenCommand = (
    payload: string,
    payloadAuth: string
  ): Promise<number> => {
    return NativeHarborLockersSDK.sendOpenLockerWithTokenCommand(
      payload,
      payloadAuth
    );
  };

  static sendOpenAvailableLockerCommand = (
    lockerToken: string,
    lockerAvailable: boolean,
    clientInfo: string,
    matchLockerType: number,
    matchAvailable: boolean,
    matchToken?: string
  ): Promise<number> => {
    return NativeHarborLockersSDK.sendOpenAvailableLockerCommand(
      lockerToken,
      lockerAvailable,
      clientInfo,
      matchLockerType,
      matchAvailable,
      matchToken
    );
  };

  static sendReopenLockerCommand = (): Promise<number> => {
    return NativeHarborLockersSDK.sendReopenLockerCommand();
  };

  static sendCheckLockerDoorCommand = (
    callback: (doorOpen: boolean) => void
  ): void => {
    NativeHarborLockersSDK.sendCheckLockerDoorCommand(callback);
  };

  static sendRevertLockerStateCommand = (
    clientInfo: string
  ): Promise<boolean> => {
    return NativeHarborLockersSDK.sendRevertLockerStateCommand(clientInfo);
  };

  static sendSetKeypadCodeCommand = (
    keypadCode: string,
    keypadCodePersists: boolean,
    keypadNextToken: string,
    keypadNextAvailable: boolean
  ): Promise<boolean> => {
    return NativeHarborLockersSDK.sendSetKeypadCodeCommand(
      keypadCode,
      keypadCodePersists,
      keypadNextToken,
      keypadNextAvailable
    );
  };

  static sendTapLockerCommand = (
    lockerTapInterval: number,
    lockerTapCount: number
  ): Promise<boolean> => {
    return NativeHarborLockersSDK.sendTapLockerCommand(
      lockerTapInterval,
      lockerTapCount
    );
  };
}

export default HarborLockersSDK;
