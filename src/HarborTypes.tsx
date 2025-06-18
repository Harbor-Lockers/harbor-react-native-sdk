export type Tower = {
  towerId: string;
  towerName: string;
  firmwareVersion: string;
  rssi: number;
};

export type SyncStatus = {
  syncEventStart: number;
  syncEventCount: number;
  syncCommandStart: number;
};

export type SyncEvents = {
  firstEventId: number;
  syncEventCount: number;
  payload: string;
  payloadAuth: string;
};

export type LockerTypesAvailability = {
  [key: string]: number; // locker types as keys, and the amount of available lockers for each type as values
};
