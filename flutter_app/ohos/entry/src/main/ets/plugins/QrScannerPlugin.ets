import common from '@ohos.app.ability.common';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import { AbilityPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';

const CHANNEL = 'hospital/qr_scanner';

export default class QrScannerPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.Context | null = null;

  getUniqueClassName(): string { return 'QrScannerPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context as common.Context;
  }

  onDetachedFromAbility(): void {
    this.context = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'scan') {
      result.notImplemented();
      return;
    }
    void this.scan(result);
  }

  private async scan(result: MethodResult): Promise<void> {
    try {
      if (this.context == null) {
        result.error('QR_SCAN_UNAVAILABLE', 'Ability context is unavailable.', null);
        return;
      }
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: false,
      };
      const scanResult = await scanBarcode.startScanForResult(this.context, options);
      const value: string = scanResult.originalValue;
      if (value) {
        result.success(value);
      } else {
        result.error('QR_EMPTY', 'No QR code was recognized.', null);
      }
    } catch (error) {
      result.error('QR_SCAN_FAILED', `${error}`, null);
    }
  }
}
