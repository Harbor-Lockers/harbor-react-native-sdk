#import "HarborLockersSDK/HarborLockersSDK-Swift.h"
#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <HarborLockersSDKSpec/HarborLockersSDKSpec.h>
@interface HarborLockersSDK : RCTEventEmitter <NativeHarborLockersSDKSpec, HarborSDKDelegate, HarborLoggerDelegate, HarborConnectionDelegate>
#else
#import <React/RCTBridgeModule.h>
@interface HarborLockersSDK : RCTEventEmitter <RCTBridgeModule, HarborSDKDelegate, HarborLoggerDelegate, HarborConnectionDelegate>
#endif

@property (nonatomic, strong) NSMutableDictionary *foundTowers;
@property (nonatomic, strong) NSMutableDictionary *cachedTowers;
@property (nonatomic, copy) dispatch_block_t dispatchBlock;

@end

