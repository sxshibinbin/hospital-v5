import common from '@ohos.app.ability.common';
import { Context as AbilityContext } from '@ohos.abilityAccessCtrl';
import hilog from '@ohos.hilog';
import Any from '@ohos/flutter_ohos/src/main/ets/plugin/common/Any';
import EventChannel, { EventSink, StreamHandler } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { AbilityPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import PhoneNumberAuthHelper, {
  AuthUIControlClickListener,
  AuthUiConfig,
  OperatorIndex,
  PageOrientation,
  TokenResultListener,
} from 'numberauth_standard';

const METHOD_CHANNEL = 'ali_auth';
const EVENT_CHANNEL = 'ali_auth/event';
const INIT_SUCCESS_CODE = '500002';
const LISTENER_MISSING_CODE = '500001';
const LOGIN_NOT_INITIALIZED_CODE = '500003';
const LOGIN_ENV_UNAVAILABLE_CODE = '500005';
const EVENT_READY_CODE = '500004';
const LOGIN_SUCCESS_CODE = '600000';
const DEFAULT_FAILURE_CODE = '700000';
const USER_AGREEMENT_URL = 'https://web.sstkjgf.com/user-agreement.html';
const PRIVACY_POLICY_URL = 'https://web.sstkjgf.com/privacy-policy.html';

interface HarmonyAuthDetails {
  authSdkCode?: string;
  accessCode?: string;
  token?: string;
  data?: string;
  isChecked?: boolean | string;
}

interface HarmonyParsedResult {
  _code?: string;
  code?: string;
  msg?: string;
  _msg?: string;
  message?: string;
  _token?: string;
  token?: string;
  data?: string;
  isChecked?: boolean | string;
  u?: HarmonyAuthDetails;
}

export default class AliAuthPlugin
  implements FlutterPlugin, AbilityAware, MethodCallHandler, StreamHandler
{
  private methodChannel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  private helper: PhoneNumberAuthHelper | null = null;
  private abilityContext: common.UIAbilityContext | null = null;
  private readonly tokenListener: TokenResultListener;
  private readonly uiClickListener: AuthUIControlClickListener;

  constructor() {
    this.tokenListener = new HarmonyTokenListener(this);
    this.uiClickListener = new HarmonyUiClickListener(this);
  }

  getUniqueClassName(): string {
    return 'AliAuthPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
    this.methodChannel.setMethodCallHandler(this);

    this.eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
    this.eventChannel.setStreamHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(null);

    this.methodChannel = null;
    this.eventChannel = null;
    this.eventSink = null;
    this.cleanupHelper();
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    const ability = binding.getAbility();
    this.abilityContext = ability.context as common.UIAbilityContext;
  }

  onDetachedFromAbility(): void {
    this.cleanupHelper();
    this.abilityContext = null;
    this.eventSink = null;
  }

  onListen(args: Any, events: EventSink): void {
    this.eventSink = events;
    events.success({
      code: EVENT_READY_CODE,
      msg: 'Harmony event listener attached',
      data: '',
      isChecked: false,
    });
  }

  onCancel(args: Any): void {
    this.eventSink = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'getPlatformVersion':
        result.success('OpenHarmony');
        return;
      case 'getSdkVersion':
        result.success('2.0.22');
        return;
      case 'initSdk':
        this.handleInitSdk(call, result);
        return;
      case 'login':
        this.handleLogin(call, result);
        return;
      case 'quitPage':
        this.handleQuitPage(result);
        return;
      case 'hideLoading':
        this.handleHideLoading(result);
        return;
      case 'getCurrentCarrierName':
        void this.handleGetCurrentCarrierName(result);
        return;
      case 'checkEnvAvailable':
        this.handleCheckEnvAvailable(call, result);
        return;
      case 'queryCheckBoxIsChecked':
        result.success(this.helper?.queryCheckBoxIsChecked() ?? false);
        return;
      case 'setCheckboxIsChecked':
        result.success(this.helper?.queryCheckBoxIsChecked() ?? false);
        return;
      case 'checkCellularDataEnable':
        result.success(false);
        return;
      case 'openPage':
        result.success(null);
        return;
      case 'appleLogin':
        result.success(null);
        return;
      default:
        result.notImplemented();
    }
  }

  handleTokenSuccess(raw: string): void {
    // The official HarmonyOS demo calls getLoginToken() directly after its
    // environment check and identifies a completed login by `_code=600000`
    // plus `_token`.  Some SDK builds add a nested `u.authSdkCode=600024` to
    // that same successful payload.  Treating that nested status as the
    // event code loses the token-success event, so Flutter never performs its
    // backend login or route transition.
    const credential = this.extractLoginCredential(raw);
    if (credential.length > 0) {
      // Do not let an informational nested authSdkCode overwrite 600000.
      // Dart dispatches the backend login exclusively from this event code.
      // Calling quitLoginPage() here (or again from Dart) makes the SDK in
      // non-Navigation mode terminate the host UIAbility (hilog showed
      // onAbilityDied -> app sent back to desktop), so the page close is
      // left entirely to the SDK.
      hilog.info(0x0000, 'AliAuthPlugin', 'token success, relying on SDK auto close');
      this.emitEvent(LOGIN_SUCCESS_CODE, 'success', credential, true);
      return;
    }

    // Environment-check callbacks are informational only.  Do not report
    // them as login successes and do not close a page that is not yet shown.
    const sdkCode = this.extractSdkCode(raw);
    this.emitParsedResult(raw, sdkCode || DEFAULT_FAILURE_CODE, raw);
  }

  handleTokenFailure(raw: string): void {
    hilog.info(0x0000, 'AliAuthPlugin', `token failure: ${raw}`);
    this.emitParsedResult(raw, DEFAULT_FAILURE_CODE, raw);
  }

  emitEvent(code: string, msg: string, data: string, isChecked: boolean): void {
    if (this.eventSink == null) {
      return;
    }

    this.eventSink.success({
      code,
      msg,
      data,
      isChecked,
    });
  }

  private handleInitSdk(call: MethodCall, result: MethodResult): void {
    if (this.eventSink == null) {
      result.error(LISTENER_MISSING_CODE, 'Please listen to the event stream first.', null);
      return;
    }

    if (this.abilityContext == null) {
      result.error(LISTENER_MISSING_CODE, 'Ability context is not ready.', null);
      return;
    }

    const harmonySk = this.readStringArg(call.argument('harmonySk'), '');
    const authKey = harmonySk;
    if (authKey.length === 0) {
      result.success({
        code: '500000',
        msg: 'Missing auth key',
        data: '',
      });
      return;
    }

    this.helper = PhoneNumberAuthHelper.getInstance(
      this.abilityContext as AbilityContext,
      this.tokenListener,
    );
    this.helper.setAuthListener(this.tokenListener);
    this.helper.setAuthSDKInfo(authKey);
    this.helper.setAuthConfig(this.buildAuthConfig(call));
    this.helper.setUIClickListener(this.uiClickListener);
    // Dialog-mode authorization page. In full-screen mode the SDK's
    // quitLoginPage() terminates the host UIAbility (hilog showed
    // onAbilityDied -> app sent back to desktop right after a successful
    // login). In dialog mode the page lives in its own window, so closing it
    // only dismisses the dialog.
    this.helper.setDialog(true);
    result.success({
      code: INIT_SUCCESS_CODE,
      msg: '\u8c03\u7528\u6210\u529f',
      data: '',
    });
  }

  private handleLogin(call: MethodCall, result: MethodResult): void {
    if (this.helper == null) {
      this.emitEvent(LOGIN_NOT_INITIALIZED_CODE, 'SDK not initialized', '', false);
      result.success(null);
      return;
    }

    const timeout = this.readNumberArg(call.argument('timeout'), 5000);

    try {
      // Keep the call order used by the vendor v2.0.23 demo. `1` is the
      // demo's login environment check; getLoginToken() must still be called
      // immediately because the SDK does not guarantee a separate success
      // callback for every environment check.
      this.helper.checkEnvAvailable(1);
      this.startLoginToken(timeout);
    } catch (error) {
      this.emitEvent(LOGIN_ENV_UNAVAILABLE_CODE, `${error}`, '', false);
    }

    result.success(null);
  }

  private startLoginToken(timeout: number): void {
    if (this.helper == null) {
      return;
    }
    void this.helper.getLoginToken(timeout).catch((error: Object) => {
      this.emitEvent(DEFAULT_FAILURE_CODE, `${error}`, '', false);
    });
  }

  private async handleQuitPage(result: MethodResult): Promise<void> {
    await this.closeLoginPage();
    result.success(null);
  }

  private async closeLoginPage(): Promise<void> {
    if (this.helper == null) {
      return;
    }

    hilog.info(0x0000, 'AliAuthPlugin', 'closeLoginPage begin');
    // There is normally no privacy dialog at token-success time. Some
    // Harmony SDK builds throw when quitPrivacyAlert() is called in that
    // state; that must not prevent the actual auth page from being closed.
    try {
      this.helper.quitPrivacyAlert();
    } catch (_) {
    }
    await this.helper.quitLoginPage();
    hilog.info(0x0000, 'AliAuthPlugin', 'closeLoginPage done');
  }

  private handleHideLoading(result: MethodResult): void {
    if (this.helper != null) {
      this.helper.o29();
    }
    result.success(null);
  }

  private async handleGetCurrentCarrierName(result: MethodResult): Promise<void> {
    if (this.helper == null) {
      result.success(null);
      return;
    }

    try {
      const carrierName = await this.helper.getCurrentCarrierName();
      result.success(this.normalizeCarrierName(carrierName));
    } catch (error) {
      result.success(null);
    }
  }

  private handleCheckEnvAvailable(call: MethodCall, result: MethodResult): void {
    if (this.helper != null) {
      // Keep this in sync with the Android plugin's checkEnvAvailable()
      // bridge: the Dart API is specifically the one-key-login check.
      const type = this.readNumberArg(call.argument('type'), 2);
      this.helper.checkEnvAvailable(type);
    }
    result.success(null);
  }

  private buildAuthConfig(call: MethodCall): AuthUiConfig {
    const config = new AuthUiConfig();
    const statusBarColor = this.readStringArg(call.argument('statusBarColor'), '#F8F3FF');
    const bottomNavColor = this.readStringArg(call.argument('bottomNavColor'), '#FFFFFF');
    const lightColor = this.readBooleanArg(call.argument('lightColor'), true);
    // AGC audit requires the agreement checkbox to be visible and off by
    // default; the phone number is sensitive personal information and must
    // not be requested before the user actively consents.
    const checkboxHidden = this.readBooleanArg(call.argument('checkboxHidden'), false);
    const privacyState = this.readBooleanArg(call.argument('privacyState'), false);
    const numberColor = this.readStringArg(call.argument('numberColor'), '#2F266F');
    const loginText = this.readStringArg(call.argument('logBtnText'), '\u672c\u673a\u4e00\u952e\u767b\u5f55');
    const loginTextColor = this.readStringArg(call.argument('logBtnTextColor'), '#FFFFFF');
    const loginMargin = this.readNumberArg(call.argument('logBtnMarginLeftAndRight'), 28);
    const loginHeight = this.readNumberArg(call.argument('logBtnHeight'), 50);
    const privacyTextSize = this.readNumberArg(call.argument('privacyTextSize'), 12);
    const privacyMargin = this.readNumberArg(call.argument('privacyMargin'), 28);
    const privacyBefore = this.readStringArg(
      call.argument('privacyBefore'),
      '\u6211\u5df2\u9605\u8bfb\u5e76\u540c\u610f',
    );
    const privacyEnd = this.readStringArg(
      call.argument('privacyEnd'),
      '\u5e76\u6388\u6743\u83b7\u53d6\u672c\u673a\u53f7\u7801',
    );
    const vendorPrivacyPrefix = this.readStringArg(call.argument('vendorPrivacyPrefix'), '\u300a');
    const vendorPrivacySuffix = this.readStringArg(call.argument('vendorPrivacySuffix'), '\u300b');

    config.windowBarProperties = {
      statusBarColor,
      isStatusBarLightIcon: lightColor,
      navigationBarColor: bottomNavColor,
    };
    // Full-viewport dialog keeps the original full-screen look while the
    // page stays in a dismissible dialog window.
    config.dialogWidth = '100%';
    config.dialogHeight = '100%';
    config.dialogAutoCancel = false;
    config.dialogMaskColor = '#00000000';
    // HarmonyOS does not expose Android's navHidden option. Blend the
    // navigation area into the page so it does not become a purple strip.
    config.navColor = '#F8F3FF';
    config.navFontColor = '#F8F3FF';
    config.navFontSize = 0;
    config.navMarginTop = 0;

    // The Harmony SDK lays out each item independently.  Margins alone do
    // not establish the item's parent anchor, which makes the login button
    // fall to the top of the page and can place the phone number underneath
    // it.  Use the SDK's documented full-screen anchors, matching the
    // official FullPortUIConfig sample.
    config.numberMargin = { top: 164 };
    config.numberAlignRuleOption = {
      middle: { anchor: '__container__', align: HorizontalAlign.Center },
      top: { anchor: '__container__', align: VerticalAlign.Top },
    };
    config.numberFontSize = 28;
    config.numberFontIsBold = true;
    config.numberFontColor = numberColor;
    config.numberWidth = '100%';
    config.numberHeight = 44;

    config.loginBtnText = loginText;
    config.loginBtnFontColor = loginTextColor;
    config.loginBtnFontSize = 16;
    // Keep the same horizontal breathing room as the Android authorization
    // page. A plain 100% width ignores the left/right margins on HarmonyOS.
    config.loginBtnWidth = 'calc(100% - 56vp)';
    config.loginBtnHeight = loginHeight;
    config.loginBtnMargin = {
      left: 0,
      right: 0,
      top: 226,
    };
    config.loginBtnAlignRuleOption = {
      middle: { anchor: '__container__', align: HorizontalAlign.Center },
      top: { anchor: '__container__', align: VerticalAlign.Top },
    };
    config.loginBtnPadding = {
      left: loginMargin,
      right: loginMargin,
      top: 0,
      bottom: 0,
    };
    config.loginBtnBackGroundColor = '#5B57F7';
    config.loginBtnDisableBackGroundColor = '#C5B9E8';
    config.loginBtnBorderColor = '#5B57F7';
    config.loginBtnDisableBorderColor = '#C5B9E8';
    config.loginBtnBorder = '18vp';
    config.loginBtnDisableFontColor = '#FFFFFF';

    config.privacyFontColor = '#8F88AE';
    config.privacyFontSize = privacyTextSize;
    config.privacyMargin = {
      left: privacyMargin,
      right: privacyMargin,
      bottom: privacyMargin,
    };
    config.privacyCbIsOn = privacyState;
    config.privacyCbTipText = '\u8bf7\u5148\u52fe\u9009\u540c\u610f\u534f\u8bae';
    if (checkboxHidden) {
      // The Harmony SDK treats a zero-sized checkbox as unchecked even when
      // privacyCbIsOn is true, then emits 700002 when the login button is
      // pressed. Keep a one-pixel checked control so the Android-style hidden
      // agreement still satisfies the SDK's internal validation.
      config.privacyCbWidth = 1;
      config.privacyCbHeight = 1;
      config.privacyCbMargin = { left: 0, right: 0, bottom: 0 };
    } else {
      config.privacyCbWidth = 20;
      config.privacyCbHeight = 20;
      config.privacyCbMargin = { left: 16, right: 5, bottom: 30 };
      // The clause text is laid out independently from the checkbox, so its
      // left margin must clear the checkbox (left 16 + width 20 + gap 5)
      // or the first line overlaps the control.
      config.privacyMargin = {
        left: 16 + 20 + 5 + 4,
        right: privacyMargin,
        bottom: privacyMargin,
      };
    }
    config.privacyCbIsOn = privacyState;
    config.privacyCbAlignRuleOption = {
      top: { anchor: 'clause_text', align: VerticalAlign.Top },
      left: { anchor: '__container__', align: HorizontalAlign.Start },
    };
    config.privacyAlignRuleOption = {
      bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
    };
    config.privacySpanBeforeText = privacyBefore;
    config.privacySpanBeforeFontColor = '#8F88AE';
    config.privacySpanBeforeFontSize = privacyTextSize;
    config.privacySpanOneText = '用户协议';
    config.privacySpanOneUrl = USER_AGREEMENT_URL;
    config.privacySpanOneFontColor = '#8F88AE';
    config.privacySpanOneFontSize = privacyTextSize;
    config.privacySpanTwoText = '隐私政策';
    config.privacySpanTwoUrl = PRIVACY_POLICY_URL;
    config.privacySpanTwoFontColor = '#8F88AE';
    config.privacySpanTwoFontSize = privacyTextSize;
    config.privacySpanThreeText = '';
    config.privacySpanThreeUrl = '';
    config.privacySpanThreeFontColor = '#8F88AE';
    config.privacySpanThreeFontSize = privacyTextSize;
    config.privacySpanEndText = privacyEnd;
    config.privacySpanEndFontColor = '#8F88AE';
    config.privacySpanEndFontSize = privacyTextSize;
    config.vendorPrivacyPrefix = vendorPrivacyPrefix;
    config.vendorPrivacySuffix = vendorPrivacySuffix;
    config.privacyOperatorIndex = OperatorIndex.END;

    config.needShowPrivacyAlert = false;

    config.pageScreenOrientation = PageOrientation.PORTRAIT;
    config.dialogWidth = '100%';
    config.dialogHeight = '100%';
    config.dialogMaskColor = '#22000000';
    config.dialogCornerRadius = 0;
    config.dialogPostionRule = { x: '0', y: '0' };
    config.dialogAutoCancel = false;
    config.webAuthDialogWidth = '100%';
    config.webAuthDialogHeight = '100%';

    return config;
  }

  private emitParsedResult(
    raw: string,
    defaultCode: string,
    defaultMsg: string,
    defaultData: string = '',
  ): void {
    let code = defaultCode;
    let msg = defaultMsg;
    let data = defaultData;
    let isChecked = false;

    const payload = this.tryParseObject(raw);
    if (payload != null) {
      const parsedCode = this.pickFirstString(
        payload._code,
        payload.code,
        payload.u?.authSdkCode,
      );
      if (parsedCode.length > 0) {
        code = parsedCode;
      }

      const parsedMsg = this.pickFirstString(payload.msg, payload._msg, payload.message);
      if (parsedMsg.length > 0) {
        msg = parsedMsg;
      }

      // The v2.0.23 vendor demo uses `_token`; retain it as the primary value
      // and support the nested fields emitted by other Harmony SDK variants.
      const parsedData = this.pickFirstString(
        payload._token,
        payload.token,
        payload.data,
        payload.u?.accessCode,
        payload.u?.token,
        payload.u?.data,
      );
      if (parsedData.length > 0) {
        data = parsedData;
      }

      const checkedValue = payload.isChecked;
      if (typeof checkedValue === 'boolean') {
        isChecked = checkedValue;
      } else if (typeof checkedValue === 'string') {
        isChecked = checkedValue.toLowerCase() === 'true';
      }
    } else if (defaultCode === LOGIN_SUCCESS_CODE) {
      data = this.readStringArg(raw, raw);
    }

    this.emitEvent(code, msg, data, isChecked);
  }

  private extractSdkCode(raw: string): string {
    const payload = this.tryParseObject(raw);
    if (payload == null) {
      return '';
    }
    return this.pickFirstString(
      payload._code,
      payload.code,
      payload.u?.authSdkCode,
    );
  }

  private extractLoginCredential(raw: string): string {
    const payload = this.tryParseObject(raw);
    if (payload == null) {
      return '';
    }
    return this.pickFirstString(
      payload._token,
      payload.token,
      payload.data,
      payload.u?.accessCode,
      payload.u?.token,
      payload.u?.data,
    );
  }

  private normalizeCarrierName(carrierName: string | null): string | null {
    if (carrierName == null) {
      return null;
    }

    const trimmed = carrierName.trim();
    if (trimmed.length === 0) {
      return null;
    }

    const upper = trimmed.toUpperCase();
    if (upper.includes('CMCC') || trimmed.includes('\u79fb\u52a8')) {
      return '\u4e2d\u56fd\u79fb\u52a8';
    }
    if (upper.includes('CUCC') || trimmed.includes('\u8054\u901a')) {
      return '\u4e2d\u56fd\u8054\u901a';
    }
    if (upper.includes('CTCC') || trimmed.includes('\u7535\u4fe1')) {
      return '\u4e2d\u56fd\u7535\u4fe1';
    }
    return trimmed;
  }

  private tryParseObject(raw: string): HarmonyParsedResult | null {
    try {
      return JSON.parse(raw) as HarmonyParsedResult;
    } catch (error) {
      return null;
    }
  }

  private pickFirstString(...values: Array<string | null | undefined>): string {
    for (const value of values) {
      if (value == null) {
        continue;
      }

      const text = value.trim();
      if (text.length > 0) {
        return text;
      }
    }
    return '';
  }

  private readStringArg(value: Any, fallback: string): string {
    if (value == null) {
      return fallback;
    }

    const text = `${value}`.trim();
    return text.length > 0 ? text : fallback;
  }

  private readBooleanArg(value: Any, fallback: boolean): boolean {
    if (value == null) {
      return fallback;
    }

    if (typeof value === 'boolean') {
      return value;
    }

    if (typeof value === 'string') {
      const normalized = value.trim().toLowerCase();
      if (normalized === 'true') {
        return true;
      }
      if (normalized === 'false') {
        return false;
      }
    }

    return fallback;
  }

  private readNumberArg(value: Any, fallback: number): number {
    if (value == null) {
      return fallback;
    }

    const parsed = Number(value);
    return Number.isNaN(parsed) ? fallback : parsed;
  }

  private readErrorText(error: Any): string {
    if (error == null) {
      return 'Unknown error';
    }

    if (typeof error === 'string') {
      return error;
    }

    if (error instanceof Error) {
      return error.message || error.toString();
    }

    return `${error}`;
  }

  private cleanupHelper(): void {
    if (this.helper != null) {
      this.closeLoginPage();
      this.helper.clearAuthListener();
    }
    this.helper = null;
    this.eventSink = null;
  }
}

class HarmonyTokenListener implements TokenResultListener {
  private owner: AliAuthPlugin;

  constructor(owner: AliAuthPlugin) {
    this.owner = owner;
  }

  onSuccess(msg: string): void {
    this.owner.handleTokenSuccess(msg);
  }

  onFailure(ret: string): void {
    this.owner.handleTokenFailure(ret);
  }
}

class HarmonyUiClickListener implements AuthUIControlClickListener {
  private owner: AliAuthPlugin;

  constructor(owner: AliAuthPlugin) {
    this.owner = owner;
  }

  onClick(code: string, jsonString: string): void {
    hilog.info(0x0000, 'AliAuthPlugin', `ui click code=${code}`);
    this.owner.emitEvent(code, jsonString, '', false);
  }
}
