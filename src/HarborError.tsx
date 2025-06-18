export type ParsedHarborError = {
  code: string;
  message: string;
  domain: string;
};

export class HarborError {
  static parse(error: any): ParsedHarborError {
    const userInfo = error?.userInfo ?? {};

    const code =
      userInfo.code?.toString?.() ||
      error.code?.toString?.() ||
      'unknown_error';

    const message =
      userInfo.description ||
      userInfo.NSLocalizedDescription ||
      error.message ||
      'Unknown error';

    const domain = userInfo.domain || error.domain || 'unknown.domain';

    return { code, message, domain };
  }
}
