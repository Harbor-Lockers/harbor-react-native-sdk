/**
 * This exposes the HarborLockersSDK native module as a JS module.
 */
import { NativeModules } from 'react-native';
import { Tower, SyncStatus, SyncEvents, LockerTypesAvailability } from './HarborTypes';

const { HarborLockersSDK } = NativeModules;

interface HarborLockersSDKInterface {
  initializeSDK(): void;
  setLogLevel(logLevel: string): void;
  isSyncing(callback: (isSyncing: boolean) => void): void;
  syncConnectedTower(): Promise<boolean>;
  setAccessToken(token: string, environment?: string): void;
  startTowersDiscovery(): void;
  connectToTowerWithIdentifier(
    towerId: string
  ): Promise<string>;
  connectToTower(
    towerId: string,
    discoveryTimeOut: number
  ): Promise<Tower>;
  sendRequestSession(
    role: number,
    errorCallback: (errorCode: number, errorMessage: string) => void,
    successCallback: () => void
  ): void;
  sendRequestSessionAdvanced(
    syncEnabled: boolean,
    duration: number,
    role: number,
    errorCallback: (errorCode: number, errorMessage: string) => void,
    successCallback: () => void
  ): void;
  sendTerminateSession(errorCode: number, errorMessage?: string): Promise<boolean>;
  sendRequestSyncStatusCommand(): Promise<SyncStatus>;
  sendSyncPullCommand(syncEventStart: number): Promise<SyncEvents>;
  sendSyncPushCommand(payload: string, payloadAuth: string): Promise<boolean>;
  sendAddClientEventCommand(clientInfo: string): Promise<boolean>;
  sendFindAvailableLockersCommand(): Promise<LockerTypesAvailability>;
  sendFindLockersWithTokenCommand(
    matchToken: string,
    matchAvailable: boolean
  ): Promise<LockerTypesAvailability>;
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
  ): Promise<number>;
  sendReopenLockerCommand(): Promise<number>;
  sendCheckLockerDoorCommand(callback: (doorOpen: boolean) => void): void;
  sendRevertLockerStateCommand(clientInfo: string): Promise<boolean>;
  sendSetKeypadCodeCommand(
    keypadCode: string,
    keypadCodePersists: boolean,
    keypadNextToken: string,
    keypadNextAvailable: boolean
  ): Promise<boolean>;
  sendTapLockerCommand(lockerTapInterval: number, lockerTapCount: number): Promise<boolean>;
}

export default HarborLockersSDK as HarborLockersSDKInterface;
