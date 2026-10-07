import common from '@ohos.app.ability.common';
import Any from '@ohos/flutter_ohos/src/main/ets/plugin/common/Any';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { AbilityPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';

const METHOD_CHANNEL = 'hospital/system';

interface OpenUrlWant {
  action: string;
  uri: string;
}

export default class SystemUrlPlugin
  implements FlutterPlugin, AbilityAware, MethodCallHandler
{
  private methodChannel: MethodChannel | null = null;
  private abilityContext: common.UIAbilityContext | null = null;

  getUniqueClassName(): string {
    return 'SystemUrlPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
    this.methodChannel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(null);
    this.methodChannel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityContext = binding.getAbility().context as common.UIAbilityContext;
  }

  onDetachedFromAbility(): void {
    this.abilityContext = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'openUrl') {
      result.notImplemented();
      return;
    }

    const url = this.readUrl(call.argument('url'));
    if (url.length === 0 || this.abilityContext == null) {
      result.error('OPEN_URL_INVALID', 'A valid URL and ability context are required.', null);
      return;
    }

    const want: OpenUrlWant = {
      action: 'ohos.want.action.viewData',
      uri: url,
    };
    this.abilityContext.startAbility(want)
      .then(() => result.success(null))
      .catch((error: Object) => result.error('OPEN_URL_FAILED', `${error}`, null));
  }

  private readUrl(value: Any): string {
    if (value == null) {
      return '';
    }
    const url = `${value}`.trim();
    return url.startsWith('https://') ? url : '';
  }
}
