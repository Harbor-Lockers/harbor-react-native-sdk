import HarborLockersSDK from './NativeHarborLockersSDK';

export type ParsedHarborError = {
  code: number;
  message: string;
  domain: string;
};

export class HarborError {
  code: number;
  message: string;
  domain: string;

  constructor({
    code,
    message,
    domain,
  }: {
    code: number;
    message: string;
    domain: string;
  }) {
    this.code = code;
    this.message = message;
    this.domain = domain;
  }

  static fromNativeError(error: any): HarborError | null {
    const userInfo = error?.userInfo ?? {};

    const rawCode = userInfo.code ?? error.code ?? null;
    const code = typeof rawCode === 'number' ? rawCode : Number(rawCode);

    const message =
      userInfo.description ||
      userInfo.NSLocalizedDescription ||
      error.message ||
      null;

    const domain = userInfo.domain || error.domain || null;

    if (isNaN(code) || message === null || domain === null) return null;

    return new HarborError({ code, message, domain });
  }

  static parse(error: any): ParsedHarborError {
    const userInfo = error?.userInfo ?? {};

    const code = userInfo.code || error.code || 0;

    const message =
      userInfo.description ||
      userInfo.NSLocalizedDescription ||
      error.message ||
      'Unknown error';

    const domain = userInfo.domain || error.domain || 'unknown.domain';

    return { code, message, domain };
  }

  isSDKError = async (): Promise<boolean> => {
    return HarborLockersSDK.isSDKError(this._asObject());
  };

  isAPIError = async (): Promise<boolean> => {
    return HarborLockersSDK.isAPIError(this._asObject());
  };

  isFirmwareError = async (): Promise<boolean> => {
    return HarborLockersSDK.isFirmwareError(this._asObject());
  };

  isAuthError = async (): Promise<boolean> => {
    return HarborLockersSDK.isAuthError(this._asObject());
  };

  isPermissionsError = async (): Promise<boolean> => {
    return HarborLockersSDK.isPermissionsError(this._asObject());
  };

  isCommunicationError = async (): Promise<boolean> => {
    return HarborLockersSDK.isCommunicationError(this._asObject());
  };

  isSessionError = async (): Promise<boolean> => {
    return HarborLockersSDK.isSessionError(this._asObject());
  };

  isHTTPError = async (): Promise<boolean> => {
    return HarborLockersSDK.isHTTPError(this._asObject());
  };

  isCancelled = async (): Promise<boolean> => {
    return HarborLockersSDK.isCancelled(this._asObject());
  };

  isBluetoothError = async (): Promise<boolean> => {
    return HarborLockersSDK.isBluetoothError(this._asObject());
  };

  isNetworkError = async (): Promise<boolean> => {
    return HarborLockersSDK.isNetworkError(this._asObject());
  };

  isRNError = async (): Promise<boolean> => {
    return HarborLockersSDK.isRNError(this._asObject());
  };

  private _asObject() {
    return {
      code: this.code,
      message: this.message,
      domain: this.domain,
    };
  }
}
