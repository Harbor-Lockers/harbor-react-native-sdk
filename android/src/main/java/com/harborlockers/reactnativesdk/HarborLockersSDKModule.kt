package com.harborlockers.reactnativesdk

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.bridge.Callback
import com.facebook.react.bridge.Promise
import android.os.Handler
import android.os.Looper
import com.facebook.common.util.Hex
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap
import com.harborlockers.sdk.API.Environment
import com.harborlockers.sdk.API.SessionPermission
import com.harborlockers.sdk.Models.Tower
import com.harborlockers.sdk.PublicInterface.HarborConnectionDelegate
import com.harborlockers.sdk.PublicInterface.HarborSDK
import com.harborlockers.sdk.PublicInterface.HarborSDKDelegate
import com.harborlockers.sdk.Utils.ErrorDomain
import com.harborlockers.sdk.Utils.HarborLogCallback
import com.harborlockers.sdk.Utils.HarborLogLevel
import java.util.Arrays
import java.util.concurrent.atomic.AtomicBoolean


@ReactModule(name = HarborLockersSDKModule.NAME)
class HarborLockersSDKModule(private val reactContext: ReactApplicationContext) :
  NativeHarborLockersSDKSpec(reactContext),
  HarborSDKDelegate,
  HarborLogCallback,
  HarborConnectionDelegate
{
  init {
    HarborSDK.init(reactContext.applicationContext)
  }

  private val SESSION_DURATION = 60 * 60 * 1
  private val DISCOVERY_TIME_OUT = 20
  private var promiseHandler: PromiseHandler? = null
  private var towerIdDiscovering: TowerId? = null
  private var isDiscoveringToConnect: Boolean = false
  private var returnTowerInfoInConnection: Boolean = false
  private val timeoutHandler = Handler(Looper.getMainLooper())
  private var foundTowers: MutableMap<TowerId, Tower> = mutableMapOf()
  private val cachedTowers: MutableMap<TowerId, Tower> = mutableMapOf()
  private var listenerCount: Int = 0
  private var listenerCountActivated = false

  override fun getName(): String {
    return NAME
  }

  private fun sendEvent(eventName: String, params: Any?) {
    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(eventName, params)
  }

  @ReactMethod
  override fun addListener(eventName: String?) {
    listenerCountActivated = true
    listenerCount++
  }

  @ReactMethod
  override fun removeListeners(count: Double) {
    listenerCount -= count.toInt()
  }

  @ReactMethod
  override fun initializeSDK() {
    foundTowers = mutableMapOf<TowerId, Tower>()
    HarborSDK.delegate = this
    HarborSDK.connectionDelegate = this
  }

  @ReactMethod
  override fun setLogLevel(logLevel: String) {
    HarborSDK.logLevel = logLevelFromString(logLevel)
    HarborSDK.harborLogCallback = this
  }

  @ReactMethod
  override fun isSyncing(callback: Callback?) {
    callback?.invoke(HarborSDK.isSyncing())
  }

  @ReactMethod
  override fun syncConnectedTower(promise: Promise?) {
    HarborSDK.sync { success, error ->
      if (error == null) {
        promise?.resolve(success)
      } else {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
      }
    }
  }

  @ReactMethod
  override fun startTowersDiscovery() {
    if (isDiscoveringToConnect) return
    foundTowers = HashMap()
    HarborSDK.startTowerDiscovery()
  }

  @ReactMethod
  override fun connectToTowerWithIdentifier(towerIdString: String, promise: Promise?) {
    connectToTowerWithIdentifierAndTimeout(towerIdString, DISCOVERY_TIME_OUT, false, promise)
  }

  @ReactMethod
  override fun connectToTower(towerIdString: String, discoveryTimeOut: Double, promise: Promise?) {
    connectToTowerWithIdentifierAndTimeout(towerIdString, discoveryTimeOut.toInt(), true, promise)
  }

  @ReactMethod
  override fun setAccessToken(token: String, environment: String?) {
    environment?.let { configureSDKEnvironment(it) }
    HarborSDK.setAccessToken(token)
  }

  private fun configureSDKEnvironment(environment: String?) {
    environment?.let {
      when {
        it.startsWith("http://") || it.startsWith("https://") -> HarborSDK.setBaseURL(it)
        else -> {
          val env = when (it.lowercase()) {
            "production" -> Environment.PRODUCTION
            "sandbox" -> Environment.SANDBOX
            else -> Environment.DEVELOPMENT
          }
          HarborSDK.setEnvironment(env)
        }
      }
    }
  }

  @ReactMethod
  override fun sendRequestSession(
    role: Double,
    errorCallback: Callback?,
    successCallback: Callback?
  ) {
    sendHarborRequestSession(role.toInt(), true, SESSION_DURATION, errorCallback, successCallback)
  }

  @ReactMethod
  override fun sendRequestSessionAdvanced(
    syncEnabled: Boolean,
    duration: Double,
    role: Double,
    errorCallback: Callback?,
    successCallback: Callback?
  ) {
    sendHarborRequestSession(role.toInt(), syncEnabled, duration.toInt(), errorCallback, successCallback)
  }

  private fun sendHarborRequestSession(role: Int, syncEnabled: Boolean, duration: Int, errorCallback: Callback?, successCallback: Callback?) {
    HarborSDK.establishSession(null, duration, syncEnabled, SessionPermission.entries[role]) { success, error ->
      if (!success) {
        if (error != null) {
          errorCallback?.invoke(error.errorCode, error.errorMessage)
        } else {
          errorCallback?.invoke(0, "Unknown error")
        }
      } else {
        successCallback?.invoke()
      }
    }
  }

  @ReactMethod
  override fun sendTerminateSession(errorCode: Double, errorMessage: String?, promise: Promise?) {
    HarborSDK.sendTerminateSession(errorCode.toInt(), errorMessage, true) { success, error ->
      if (error == null) {
        promise?.resolve(success)
      } else {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
      }
    }
  }

  @ReactMethod
  override fun sendRequestSyncStatusCommand(promise: Promise?) {
    HarborSDK.sendRequestSyncStatus { syncEventStart, syncEventCount, syncCommandStart, error ->
      if (error != null) {
        promise?.resolve(null)
        return@sendRequestSyncStatus
      }

      val responseMap = Arguments.createMap().apply {
        putInt("syncEventStart", syncEventStart)
        putInt("syncEventCount", syncEventCount)
        putInt("syncCommandStart", syncCommandStart)
      }
      promise?.resolve(responseMap)
    }
  }

  @ReactMethod
  override fun sendSyncPullCommand(syncEventStart: Double, promise: Promise?) {
    HarborSDK.sendSyncPull(syncEventStart.toInt()) { firstEventId, syncEventCount, payload, payloadAuth, error ->
      if (error != null) {
        promise?.resolve(null)
        return@sendSyncPull
      }

      val responseMap = Arguments.createMap().apply {
        putInt("firstEventId", firstEventId)
        putInt("syncEventCount", syncEventCount)
        putString("payload", hexString(payload))
        putString("payloadAuth", hexString(payloadAuth))
      }
      promise?.resolve(responseMap)
    }
  }

  @ReactMethod
  override fun sendSyncPushCommand(payload: String, payloadAuth: String, promise: Promise?) {
    HarborSDK.sendSyncPush(byteArray(payload), byteArray(payloadAuth)) { success, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendSyncPush
      }
      promise?.resolve(success)
    }
  }

  @ReactMethod
  override fun sendAddClientEventCommand(clientInfo: String, promise: Promise?) {
    HarborSDK.sendAddClientEvent(byteArray(clientInfo)) { success, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendAddClientEvent
      }
      promise?.resolve(success)
    }
  }

  @ReactMethod
  override fun sendFindAvailableLockersCommand(promise: Promise?) {
    HarborSDK.sendFindAvailableLockers { availableLockers, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendFindAvailableLockers
      }
      val availabilityWritableMap = Arguments.createMap()
      for ((key, value) in availableLockers) {
        availabilityWritableMap.putInt(key.toString(), value.toInt())
      }
      promise?.resolve(availabilityWritableMap)
    }
  }

  @ReactMethod
  override fun sendOpenLockerWithTokenCommand(
    payload: String,
    payloadAuth: String,
    promise: Promise?
  ) {
    HarborSDK.sendOpenLockerWithToken(byteArray(payload), byteArray(payloadAuth)) { lockerId, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendOpenLockerWithToken
      }
      promise?.resolve(lockerId)
    }
  }

  @ReactMethod
  override fun sendFindLockersWithTokenCommand(
    matchToken: String,
    matchAvailable: Boolean,
    promise: Promise?
  ) {
    HarborSDK.sendFindLockersWithToken(matchAvailable, byteArray(matchToken)) { availableLockers, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendFindLockersWithToken
      }
      val availabilityWritableMap = Arguments.createMap()
      for ((key, value) in availableLockers) {
        availabilityWritableMap.putInt(key.toString(), value.toInt())
      }
      promise?.resolve(availabilityWritableMap)
    }
  }

  @ReactMethod
  override fun sendOpenAvailableLockerCommand(
    lockerToken: String,
    lockerAvailable: Boolean,
    clientInfo: String,
    matchLockerType: Double,
    matchAvailable: Boolean,
    matchToken: String?,
    promise: Promise?
  ) {
    val matchTokenData = matchToken?.let { byteArray(it) }
    HarborSDK.sendOpenAvailableLocker(matchLockerType.toInt(), matchAvailable, matchTokenData, byteArray(lockerToken), lockerAvailable, byteArray(clientInfo)) { lockerId, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendOpenAvailableLocker
      }
      promise?.resolve(lockerId)
    }
  }

  @ReactMethod
  override fun sendReopenLockerCommand(promise: Promise?) {
    HarborSDK.sendReopenLocker() { lockerId, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendReopenLocker
      }
      promise?.resolve(lockerId)
    }
  }

  @ReactMethod
  override fun sendCheckLockerDoorCommand(callback: Callback?) {
    HarborSDK.sendCheckLockerDoor { doorOpened, error ->
      callback?.invoke(doorOpened)
    }
  }

  @ReactMethod
  override fun sendRevertLockerStateCommand(clientInfo: String, promise: Promise?) {
    HarborSDK.sendRevertLockerState(byteArray(clientInfo)) { success, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendRevertLockerState
      }
      promise?.resolve(success)
    }
  }

  @ReactMethod
  override fun sendSetKeypadCodeCommand(
    keypadCode: String,
    keypadCodePersists: Boolean,
    keypadNextToken: String,
    keypadNextAvailable: Boolean,
    promise: Promise?
  ) {
    HarborSDK.sendSetKeypadCode(keypadCode, keypadCodePersists, byteArray(keypadNextToken), keypadNextAvailable) { success, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendSetKeypadCode
      }
      promise?.resolve(success)
    }
  }

  @ReactMethod
  override fun sendTapLockerCommand(
    lockerTapInterval: Double,
    lockerTapCount: Double,
    promise: Promise?
  ) {
    HarborSDK.sendTapLocker(lockerTapInterval.toInt(), lockerTapCount.toInt()) { success, error ->
      if (error != null) {
        HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, error.errorCode, error.errorMessage, error.domain.domainName)
        return@sendTapLocker
      }
      promise?.resolve(success)
    }
  }

  override fun harborDidDiscoverTowers(towers: List<Tower>) {
    val params = Arguments.createArray()
    for (tower in towers) {
      try {
        val towerId = TowerId(tower.towerId)
        foundTowers[towerId] = tower
        cachedTowers[towerId] = tower

        if (listenerCount > 0) {
          val towerMap = Arguments.createMap()
          towerMap.putString("towerId", tower.towerId?.let { hexString(it) })
          towerMap.putString("towerName", tower.towerName)
          towerMap.putString("firmwareVersion", tower.fwVersion)
          towerMap.putInt("rssi", tower.RSSI)
          params.pushMap(towerMap)
        }

        if (isDiscoveringToConnect && towerId == towerIdDiscovering) {
          didFinishDiscoveryToConnect()
          connectToHarborTower(tower)
        }
      } catch (ex: InvalidTowerId) {
        // If invalid tower id, avoid adding the tower to the array
      }
    }

    if (listenerCount > 0) {
      sendEvent("TowersFound", params)
    }
  }

  override fun onHarborLog(message: String, logType: HarborLogLevel, context: Map<String, Any>?) {
    if (listenerCountActivated && listenerCount <= 0) return

    val params = Arguments.createMap()
    params.putString("message", message)
    params.putString("logType", logType.name)
    context?.let {
      params.putMap("context", toWritableMap(it))
    }

    sendEvent("HarborLogged", params)
  }

  override fun onTowerDisconnected(tower: Tower?) {
    if (tower == null || (listenerCountActivated && listenerCount <= 0)) return

    val towerMap = Arguments.createMap().apply {
      putString("towerId", tower.towerId?.let { hexString(it) })
      putString("towerName", tower.towerName)
      putString("firmwareVersion", tower.fwVersion)
      putInt("rssi", tower.RSSI)
    }

    sendEvent("TowerDisconnected", towerMap)
  }

  private fun connectToTowerWithIdentifierAndTimeout(
    towerIdString: String,
    discoveryTimeOut: Int,
    shouldReturnTowerInfo: Boolean,
    promise: Promise?
  ) {
    if (isDiscoveringToConnect) {
      HarborRNErrorUtil.rejectPromiseWithRNHarborError(promise, RNErrorCode.ALREADY_IN_DISCOVERY.rnCode, RNErrorCode.ALREADY_IN_DISCOVERY.description)
      return
    }

    val towerId: TowerId?
    try {
      towerId = TowerId(towerIdString)
    } catch (ex: InvalidTowerId) {
      HarborRNErrorUtil.rejectPromiseWithRNHarborError(promise, RNErrorCode.INVALID_TOWER_ID.rnCode, "Tower Id should be an String with 16 hexadecimal characters")
      return
    } catch (ex: Exception) {
      HarborRNErrorUtil.rejectPromiseWithRNHarborError(promise, RNErrorCode.INVALID_TOWER_ID.rnCode, "Invalid Tower id")
      return
    }

    returnTowerInfoInConnection = shouldReturnTowerInfo
    promiseHandler = PromiseHandler(promise)

    val towerToConnect = cachedTowers[towerId]
    if (towerToConnect != null) {
      connectToHarborTower(towerToConnect)
      return
    } else {
      discoverAndConnect(towerId, discoveryTimeOut)
    }
  }

  private fun connectToHarborTower(towerToConnect: Tower) {
    HarborSDK.connectToTower(towerToConnect) { towerName, error ->
      if (promiseHandler == null) {
        return@connectToTower
      }

      if (error != null) {
        promiseHandler?.safelyRejectNative(error.errorCode, error.errorMessage, error.domain.domainName)
        return@connectToTower
      }

      if (towerName == null) return@connectToTower

      if (returnTowerInfoInConnection) {
        val towerMap = Arguments.createMap().apply {
          putString("towerId", towerToConnect.towerId?.let { hexString(it) })
          putString("towerName", towerToConnect.towerName)
          putString("firmwareVersion", towerToConnect.fwVersion)
          putInt("rssi", towerToConnect.RSSI)
        }
        promiseHandler?.safelyResolve(towerMap)
      } else {
        promiseHandler?.safelyResolve(towerName)
      }
    }
  }

  private fun discoverAndConnect(towerId: TowerId, discoveryTimeOut: Int) {
    isDiscoveringToConnect = true
    towerIdDiscovering = towerId
    HarborSDK.startTowerDiscovery()

    timeoutHandler.postDelayed({
      if (isDiscoveringToConnect) {
        didFinishDiscoveryToConnect()
        promiseHandler?.safelyRejectRN(RNErrorCode.DISCOVERY_TIMEOUT.rnCode, RNErrorCode.DISCOVERY_TIMEOUT.description)
      }
    }, discoveryTimeOut * 1000L)
  }

  private fun didFinishDiscoveryToConnect() {
    timeoutHandler.removeCallbacksAndMessages(null)
    isDiscoveringToConnect = false
    towerIdDiscovering = null
  }

  private fun toWritableMap(map: Map<String, *>): WritableMap {
    val writableMap = Arguments.createMap()
    for ((key, value) in map) {
      when (value) {
        null -> writableMap.putNull(key)
        is Boolean -> writableMap.putBoolean(key, value)
        is Double -> writableMap.putDouble(key, value)
        is Int -> writableMap.putInt(key, value)
        is String -> writableMap.putString(key, value)
        is Map<*, *> -> writableMap.putMap(key, toWritableMap(value as Map<String, *>))
        is Array<*> -> writableMap.putArray(key, toWritableArray(value))
        else -> {} // unsupported type
      }
    }
    return writableMap
  }

  private fun toWritableArray(array: Array<*>): WritableArray {
    val writableArray = Arguments.createArray()
    for (value in array) {
      when (value) {
        null -> writableArray.pushNull()
        is Boolean -> writableArray.pushBoolean(value)
        is Double -> writableArray.pushDouble(value)
        is Int -> writableArray.pushInt(value)
        is String -> writableArray.pushString(value)
        is Map<*, *> -> writableArray.pushMap(toWritableMap(value as Map<String, *>))
        is Array<*> -> writableArray.pushArray(toWritableArray(value))
        else -> {}
      }
    }
    return writableArray
  }

  private fun hexString(bytes: ByteArray): String {
    return Hex.encodeHex(bytes, false)
  }

  private fun byteArray(s: String): ByteArray {
    val len = s.length
    require(len % 2 == 0) { "Hex string must have even length" }

    return ByteArray(len / 2) { i ->
      val index = i * 2
      ((Character.digit(s[index], 16) shl 4) + Character.digit(s[index + 1], 16)).toByte()
    }
  }

  private fun logLevelFromString(logLevel: String): HarborLogLevel {
    return when (logLevel.lowercase()) {
      "debug" -> HarborLogLevel.DEBUG
      "verbose" -> HarborLogLevel.VERBOSE
      "warning" -> HarborLogLevel.WARNING
      "error" -> HarborLogLevel.ERROR
      else -> HarborLogLevel.INFO
    }
  }

  companion object {
    const val NAME = "HarborLockersSDK"
  }
}

open class ByteArrayKey {
  protected var data: ByteArray = ByteArray(0)

  constructor()

  constructor(data: ByteArray) {
    this.data = data
  }

  override fun hashCode(): Int {
    return data.contentHashCode()
  }

  override fun equals(other: Any?): Boolean {
    if (this === other) return true
    if (other == null || this::class != other::class) return false
    val otherKey = other as ByteArrayKey
    return data.contentEquals(otherKey.data)
  }
}

class TowerId : ByteArrayKey {

  @Throws(InvalidTowerId::class)
  constructor(hexString: String?) : super() {
    if (hexString == null || hexString.length != 16) {
      throw InvalidTowerId("Invalid tower Id length, should be 16 characters")
    }

    val length = hexString.length / 2
    data = ByteArray(length)

    for (i in 0 until length) {
      val byteString = hexString.substring(i * 2, i * 2 + 2)
      val byteValue = byteString.toInt(16)
      data[i] = byteValue.toByte()
    }
  }

  @Throws(InvalidTowerId::class)
  constructor(towerIdBytes: ByteArray?) : super(
    towerIdBytes ?: throw InvalidTowerId("Tower ID cannot be null")
  ) {
    if (towerIdBytes.size != 8) {
      throw InvalidTowerId("Invalid tower Id length, should be 8 bytes")
    }
  }
}

class InvalidTowerId(message: String) : Exception(message)

class PromiseHandler(private val promise: Promise?) {
  private val isActive = AtomicBoolean(true)

  fun safelyRejectNative(code: Int, reason: String, domain: String) {
    if (isActive.getAndSet(false) && promise != null) {
      HarborRNErrorUtil.rejectPromiseWithNativeHarborError(promise, code, reason, domain)
    }
  }

  fun safelyRejectRN(code: String, reason: String) {
    if (isActive.getAndSet(false) && promise != null) {
      HarborRNErrorUtil.rejectPromiseWithRNHarborError(promise, code, reason)
    }
  }

  fun safelyResolve(response: Any?) {
    if (isActive.getAndSet(false) && promise != null) {
      promise.resolve(response)
    }
  }
}

object HarborRNErrorUtil {
  fun rejectPromiseWithRNHarborError(
    promise: Promise?,
    code: String,
    description: String
  ) {
    val errorMap = Arguments.createMap().apply {
      putInt("code", RNErrorCode.fromRNCode(code).userInfoCode)
      putString("description", description)
      putString("domain", "sdk.rn")
    }

    promise?.reject(
      code,
      description,
      errorMap
    )
  }

  fun rejectPromiseWithNativeHarborError(
    promise: Promise?,
    code: Int,
    description: String,
    domain: String = ErrorDomain.SDK.domainName
  ) {
    val errorMap = Arguments.createMap().apply {
      putInt("code", code)
      putString("description", description)
      putString("domain", domain)
    }

    promise?.reject(
      code.toString(),
      description,
      errorMap
    )
  }
}

enum class RNErrorCode(val rnCode: String, val userInfoCode: Int, val description: String) {
  UNKNOWN("unknown_error", 0, "Unknown error in React Native"),
  ALREADY_IN_DISCOVERY("already_in_discovery", 1, "Already discovering towers to connect"),
  DISCOVERY_TIMEOUT("discovery_timeout", 2, "Discovery timeout, tower not found"),
  INVALID_TOWER_ID("invalid_tower_id", 3, "Invalid tower id");

  companion object {
    fun fromRNCode(code: String): RNErrorCode {
      return entries.find { it.rnCode == code } ?: UNKNOWN
    }
  }
}
