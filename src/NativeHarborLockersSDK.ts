import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

import type {
  Tower,
  SyncStatus,
  SyncEvents,
  LockerTypesAvailability,
} from './HarborTypes';

export interface Spec extends TurboModule {
  initializeSDK(): void;
  setLogLevel(logLevel: string): void;
  isSyncing(callback: (isSyncing: boolean) => void): void;
  syncConnectedTower(): Promise<boolean>;
  setAccessToken(token: string, environment?: string | null): void;
  startTowersDiscovery(): void;
  connectToTowerWithIdentifier(towerId: string): Promise<string>;
  connectToTower(towerId: string, discoveryTimeOut: number): Promise<Tower>;
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
  sendTerminateSession(
    errorCode: number,
    errorMessage?: string
  ): Promise<boolean>;
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
  sendTapLockerCommand(
    lockerTapInterval: number,
    lockerTapCount: number
  ): Promise<boolean>;
  addListener(eventName: string): void;
  removeListeners(count: number): void;
  isSDKError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isAPIError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isFirmwareError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isAuthError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isPermissionsError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isCommunicationError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isSessionError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isHTTPError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isCancelled(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isBluetoothError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isNetworkError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
  isRNError(error: {
    code: number;
    domain: string;
    message: string;
  }): Promise<boolean>;
}

export const DEFAULT_TOWER_ID = '0000000000000000';

export default TurboModuleRegistry.getEnforcing<Spec>('HarborLockersSDK');
