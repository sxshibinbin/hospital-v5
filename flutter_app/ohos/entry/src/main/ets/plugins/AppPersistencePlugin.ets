import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import Any from '@ohos/flutter_ohos/src/main/ets/plugin/common/Any';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { AbilityPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';

const CHANNEL = 'hospital/persistence';
const STORE_NAME = 'hospital_app_state';

export default class AppPersistencePlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.Context | null = null;

  getUniqueClassName(): string { return 'AppPersistencePlugin'; }

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

  onDetachedFromAbility(): void { this.context = null; }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    void this.handle(call, result);
  }

  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.context == null) {
      result.error('PERSISTENCE_UNAVAILABLE', 'Ability context is unavailable.', null);
      return;
    }
    const key = this.readString(call.argument('key'));
    if (key.length === 0) {
      result.error('PERSISTENCE_INVALID_KEY', 'A storage key is required.', null);
      return;
    }
    try {
      const store = await preferences.getPreferences(this.context, STORE_NAME);
      if (call.method === 'readString') {
        result.success(store.getSync(key, '') as string);
      } else if (call.method === 'writeString') {
        store.putSync(key, this.readString(call.argument('value')));
        await store.flush();
        result.success(null);
      } else if (call.method === 'readBool') {
        result.success(store.getSync(key, false) as boolean);
      } else if (call.method === 'writeBool') {
        store.putSync(key, call.argument('value') === true);
        await store.flush();
        result.success(null);
      } else {
        result.notImplemented();
      }
    } catch (error) {
      result.error('PERSISTENCE_FAILED', `${error}`, null);
    }
  }

  private readString(value: Any): string { return value == null ? '' : `${value}`; }
}
