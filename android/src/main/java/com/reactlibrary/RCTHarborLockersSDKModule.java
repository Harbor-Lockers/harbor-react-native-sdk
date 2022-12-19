package com.reactlibrary;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.common.util.Hex;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

import java.util.Date;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.harborlockers.sdk.PublicInterface.HarborSDK;
import com.harborlockers.sdk.PublicInterface.HarborSDKDelegate;
import com.harborlockers.sdk.API.Environment;
import com.harborlockers.sdk.API.SessionPermission;
import com.harborlockers.sdk.Models.Tower;
import com.harborlockers.sdk.Utils.HarborLogLevel;
import com.harborlockers.sdk.Utils.HarborLogCallback;

import org.jetbrains.annotations.NotNull;

public class RCTHarborLockersSDKModule extends ReactContextBaseJavaModule implements HarborSDKDelegate, HarborLogCallback {
    public RCTHarborLockersSDKModule(ReactApplicationContext context) {
        super(context);
        reactContext = context;
        HarborSDK.INSTANCE.init(context.getApplicationContext());
    }
    private final ReactApplicationContext reactContext;
    private Map<String, Tower> foundTowers;
    private int listenerCount = 0;

    @NonNull
    @Override
    public String getName() {
        return "HarborLockersSDK";
    }

    private void sendEvent(ReactContext reactContext,
                           String eventName,
                           @Nullable Object params) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

    // Required for rn built in EventEmitter Calls.
    @ReactMethod
    public void addListener(String eventName) {
        listenerCount++;
    }

    // Required for rn built in EventEmitter Calls.
    @ReactMethod
    public void removeListeners(Integer count) {
        listenerCount -= count;
    }

    //region ------ SDK Management Methods ------

    @ReactMethod
    public void initializeSDK() {
        HarborSDK.INSTANCE.setDelegate(this);
    }

    @ReactMethod
    public void setLogLevel(String logLevel) {
        HarborSDK.INSTANCE.setLogLevel(logLevelFromString(logLevel));
        HarborSDK.INSTANCE.setHarborLogCallback(this);
    }

    @ReactMethod
    public void isSyncing(Callback callback) {
        callback.invoke(HarborSDK.INSTANCE.isSyncing());
    }

    @ReactMethod
    public void syncConnectedTower(Promise promise) {
        HarborSDK.INSTANCE.sync((success, error) -> {
            if (success) {
                promise.resolve(true);
            } else if (error != null) {
                promise.reject(String.valueOf(error.getErrorCode()), error.getErrorMessage());
            } else {
                promise.reject("sync_error", "Sync failed");
            }
            return null;
        });
    }

    @ReactMethod
    public void startTowersDiscovery() {
        foundTowers = new HashMap<>();
        HarborSDK.INSTANCE.startTowerDiscovery();
    }

    @ReactMethod
    public void connectToTowerWithIdentifier(String towerId, Promise promise) {
        Tower towerToConnect = foundTowers.get(towerId);
        if (towerToConnect != null) {
            HarborSDK.INSTANCE.connectToTower(towerToConnect, (towerName, error) -> {
                if (error == null) {
                    WritableArray connectedTowerParam = Arguments.createArray();
                    connectedTowerParam.pushString(towerName);
                    promise.resolve(connectedTowerParam);
                } else {
                    promise.reject(String.valueOf(1), error.getMessage());
                }
                return null;
            });
        }
    }
    //endregion

    //region ------ API Methods ------
    @ReactMethod
    public void loginWithEmail(String email, String password, String environment, Promise promise) {
        configureSDKEnvironment(environment);
        HarborSDK.INSTANCE.loginWithEmail(email, password, (resultCode, error, apiError) -> {
            if (apiError == null) {
                promise.resolve(resultCode);
            } else {
                promise.reject(String.valueOf(resultCode), apiError.getErrorMessage());
            }
            return null;
        });
    }

    @ReactMethod
    public void setAccessToken(String token, @Nullable String environment) {
        if (environment != null) {
            configureSDKEnvironment(environment);
        }
        HarborSDK.INSTANCE.setAccessToken(token);
    }

    private void configureSDKEnvironment(@Nullable String environment) {
        Environment env = Environment.DEVELOPMENT;
        if (environment.toLowerCase().contentEquals("production")) {
            env = Environment.PRODUCTION;
        } else if (environment.toLowerCase().contentEquals("sandbox")) {
            env = Environment.SANDBOX;
        } else if (environment.startsWith("http://") || environment.startsWith("https://")) {
            HarborSDK.INSTANCE.setBaseURL(environment);
        }
        HarborSDK.INSTANCE.setEnvironment(env);
    }
    //endregion

    //region ------ Session Commands ------
    @ReactMethod
    public void sendRequestSession(Integer role, Callback errorCallback, Callback successCallback) {
        HarborSDK.INSTANCE.establishSession(null, 600, SessionPermission.values()[role], (success, error) -> {
            if(!success) {
                if (error != null) {
                    errorCallback.invoke(error.getErrorCode(), error.getErrorMessage());
                } else {
                    errorCallback.invoke(0, "Unknown error");
                }
            } else {
                successCallback.invoke();
            }
            return null;
        });
    }

    @ReactMethod
    public void sendTerminateSession(Integer errorCode, @Nullable String errorMessage) {
        HarborSDK.INSTANCE.sendTerminateSession(errorCode, errorMessage, true, null);
    }
    //endregion

    //region ------ Keys Management Commands ------
    @ReactMethod
    public void sendInstallKeyCommand(double keyId, double keyRotation, double keyExpires, String keyData, String keyLocator) {
        HarborSDK.INSTANCE.sendInstallKey((int)keyId, (int)keyRotation, new Date((long)keyExpires * 1000), byteArray(keyData), keyLocator, null);
    }

    @ReactMethod
    public void sendSunsetKeyCommand(double keyId, double keyRotation) {
        HarborSDK.INSTANCE.sendSunsetKey((int)keyId, (int)keyRotation, null);
    }

    @ReactMethod
    public void sendRevokeKeyCommand(double keyId, double keyRotation) {
        HarborSDK.INSTANCE.sendRevokeKey((int)keyId, (int)keyRotation, null);
    }
    //endregion

    //region ------ Sync Events Commands ------
    @ReactMethod
    public void sendRequestSyncStatusCommand() {
        HarborSDK.INSTANCE.sendRequestSyncStatus((syncEventStart, syncEventCount, syncCommandStart, error) -> null);
    }

    @ReactMethod
    public void sendSyncPullCommand(double syncEventStart) {
        HarborSDK.INSTANCE.sendSyncPull((int)syncEventStart, (firstEventId, syncEventCount, payload, payloadAuth, error) -> null);
    }

    @ReactMethod
    public void sendSyncPushCommand(String payload, String payloadAuth) {
        HarborSDK.INSTANCE.sendSyncPush(byteArray(payload), byteArray(payloadAuth), null);
    }

    @ReactMethod
    public void sendMarkSeenEventsCommand(double syncEventStart) {
        HarborSDK.INSTANCE.sendMarkSeenEvents((int)syncEventStart, null);
    }

    @ReactMethod
    public void sendResetEventCounterCommand(double syncEventStart) {
        HarborSDK.INSTANCE.sendResetEventCounter((int)syncEventStart, null);
    }

    @ReactMethod
    public void sendResetCommandCounterCommand(double syncCommandStart) {
        HarborSDK.INSTANCE.sendResetCommandCounter((int)syncCommandStart, null);
    }

    @ReactMethod
    public void sendAddClientEventCommand(String clientInfo) {
        HarborSDK.INSTANCE.sendAddClientEvent(byteArray(clientInfo), null);
    }
    //endregion

    //region ------ Sync Events Commands ------
    @ReactMethod
    public void sendFindAvailableLockersCommand() {
        HarborSDK.INSTANCE.sendFindAvailableLockers((availableLockers, error) -> null);
    }

    @ReactMethod
    public void sendOpenLockerWithTokenCommand(String payload, String payloadAuth, Promise promise) {
        HarborSDK.INSTANCE.sendOpenLockerWithToken(byteArray(payload), byteArray(payloadAuth), (lockerId, harborError) -> {
            if (harborError == null && lockerId > -1) {
                promise.resolve(lockerId);
            } else {
                promise.reject(String.valueOf(lockerId), harborError.getErrorMessage());
            }
            return null;
        });
    }

    @ReactMethod
    public void sendFindLockersWithTokenCommand(String matchToken, boolean matchAvailable) {
        HarborSDK.INSTANCE.sendFindLockersWithToken(matchAvailable, byteArray(matchToken), null);
    }

    @ReactMethod
    public void sendOpenAvailableLockerCommand(String lockerToken,
                                               boolean lockerAvailable,
                                               String clientInfo,
                                               double matchLockerType,
                                               boolean matchAvailable,
                                               String matchToken) {
        HarborSDK.INSTANCE.sendOpenAvailableLocker(
                (int)matchLockerType,
                matchAvailable,
                byteArray(matchToken),
                byteArray(lockerToken),
                lockerAvailable,
                byteArray(clientInfo),
                null);
    }

    @ReactMethod
    public void sendReopenLockerCommand() {
        HarborSDK.INSTANCE.sendReopenLocker(null);
    }

    @ReactMethod
    public void sendCheckLockerDoorCommand(Callback callback) {
        HarborSDK.INSTANCE.sendCheckLockerDoor((doorOpened, harborError) -> {
            callback.invoke(doorOpened);
            return null;
        });
    }

    @ReactMethod
    public void sendRevertLockerStateCommand(String clientInfo) {
        HarborSDK.INSTANCE.sendRevertLockerState(byteArray(clientInfo), null);
    }

    @ReactMethod
    public void sendSetKeypadCodeCommand(String keypadCode, Boolean keypadCodePersists, String keypadNextToken, Boolean keypadNextAvailable) {
        HarborSDK.INSTANCE.sendSetKeypadCode(keypadCode, keypadCodePersists, byteArray(keypadNextToken), keypadNextAvailable, null);
    }

    @ReactMethod
    public void sendTapLockerCommand(double lockerTapIntervalMS, double lockerTapCount) {
        HarborSDK.INSTANCE.sendTapLocker((int)lockerTapIntervalMS, (int)lockerTapCount, null);
    }

    @ReactMethod
    public void sendCheckAllLockerDoorsCommand() {
        HarborSDK.INSTANCE.sendCheckAllLockerDoors(null);
    }
    //endregion

    //region ------ HarborSDKDelegate methods ------
    @Override
    public void harborDidDiscoverTowers(@NotNull List<Tower> towers) {
        if(listenerCount <= 0) {
            return;
        }

        WritableArray params = Arguments.createArray();
        for (Tower tower : towers) {
            foundTowers.put(hexString(tower.getTowerId()), tower);
            WritableMap towerMap = Arguments.createMap();
            towerMap.putString("towerId", hexString(tower.getTowerId()));
            towerMap.putString("towerName", tower.getTowerName());
            params.pushMap((ReadableMap) towerMap);
        }
        sendEvent(reactContext, "TowersFound", params);
    }
    //endregion

    //region ------ HarborLogCallback methods ------
    @Override
    public void onHarborLog(@NonNull String message, @NonNull HarborLogLevel logType, @Nullable Map<String, ?> context) {
        if(listenerCount <= 0) {
            return
        };

        WritableMap params = Arguments.createMap();
        params.putString("message",message);
        params.putString("logType",logType.name());
        if(context!=null){
            params.putMap("context", toWritableMap(context));
        }
        sendEvent(reactContext, "HarborLogged", params);
    }
    //endregion

    //region ------ Helper methods ------
    public static WritableMap toWritableMap(Map<String, ?> map) {
        WritableMap writableMap = Arguments.createMap();
        Iterator iterator = map.entrySet().iterator();

        while (iterator.hasNext()) {
            Map.Entry<String, ?> pair = (Map.Entry) iterator.next();
            Object value = pair.getValue();

            if (value == null) {
                writableMap.putNull(pair.getKey());
            } else if (value instanceof Boolean) {
                writableMap.putBoolean(pair.getKey(), (Boolean) value);
            } else if (value instanceof Double) {
                writableMap.putDouble(pair.getKey(), (Double) value);
            } else if (value instanceof Integer) {
                writableMap.putInt(pair.getKey(), (Integer) value);
            } else if (value instanceof String) {
                writableMap.putString(pair.getKey(), (String) value);
            } else if (value instanceof Map) {
                writableMap.putMap(pair.getKey(), toWritableMap((Map<String, ?>) value));
            } else if (value.getClass() != null && value.getClass().isArray()) {
                writableMap.putArray(pair.getKey(), toWritableArray((Object[]) value));
            }
        }

        return writableMap;
    }

    public static WritableArray toWritableArray(Object[] array) {
        WritableArray writableArray = Arguments.createArray();

        for (int i = 0; i < array.length; i++) {
            Object value = array[i];

            if (value == null) {
                writableArray.pushNull();
            }
            if (value instanceof Boolean) {
                writableArray.pushBoolean((Boolean) value);
            }
            if (value instanceof Double) {
                writableArray.pushDouble((Double) value);
            }
            if (value instanceof Integer) {
                writableArray.pushInt((Integer) value);
            }
            if (value instanceof String) {
                writableArray.pushString((String) value);
            }
            if (value instanceof Map) {
                writableArray.pushMap(toWritableMap((Map<String, ?>) value));
            }
            if (value.getClass().isArray()) {
                writableArray.pushArray(toWritableArray((Object[]) value));
            }
        }

        return writableArray;
    }

    private String hexString(byte[] bytes) {
        return Hex.encodeHex(bytes, false);
    }
    /* s must be an even-length string. */
    private byte[] byteArray(String s) {
        int len = s.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                    + Character.digit(s.charAt(i+1), 16));
        }
        return data;
    }

    private HarborLogLevel logLevelFromString(String logLevel) {
        if (logLevel == null) return HarborLogLevel.INFO;

        if (logLevel.toLowerCase().contentEquals("debug")) {
            return HarborLogLevel.DEBUG;
        } else if (logLevel.toLowerCase().contentEquals("verbose")) {
            return HarborLogLevel.VERBOSE;
        } else if (logLevel.toLowerCase().contentEquals("warning")) {
            return HarborLogLevel.WARNING;
        } else if (logLevel.toLowerCase().contentEquals("error")) {
            return HarborLogLevel.ERROR;
        }else{
            return HarborLogLevel.INFO;
        }
    }
    //endregion
}