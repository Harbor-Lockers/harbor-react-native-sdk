# harbor-react-native-sdk Documentation

## Getting started

`$ npm install @harborlockers/react-native-sdk --save`
or
`$ yarn add @harborlockers/react-native-sdk`

## Example usage from React Native
```javascript
import HarborSDK from '@harborlockers/react-native-sdk';

// Use any of the Harbor SDK methods
HarborSDK.initializeSDK()
HarborSDK.setAccessToken(session.sdkToken, Config.ENV);
```

Before getting started with the SDK, you will need to integrate your backend with the Harbor Backend. This is required to connect and interact with the Harbor Towers.

For steps on how to use this SDK to connect and interact with the tower, please refer to our [official documentation](https://docs.harborlockers.com/getting_started_with_sdk.html)