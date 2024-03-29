/**
 * This exposes the HarborLockersSDK native module as a JS module.
 */
import { NativeModules } from 'react-native';

const { HarborLockersSDK } = NativeModules;

interface HarborLockersSDKInterface {
  initializeSDK(): void;
  setLogLevel(logLevel: string): void;
  isSyncing(callback: (isSyncing: boolean) => void): void;
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
}

export default HarborLockersSDK as HarborLockersSDKInterface;
