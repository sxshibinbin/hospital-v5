// @keepTs
// @ts-nocheck
import { TokenResultListener } from "../h/k/n";
import s13 from "../h/z1/o2";
import { PreLoginResultListener } from "../h/k/m";
import { AuthUIControlClickListener } from "../h/k/l";
import { Context as Context } from "@ohos.abilityAccessCtrl";
import { AuthUiConfig } from "../f/AuthUiConfig";
export declare class PhoneNumberAuthHelper {
    private static instance;
    private t22;
    private e29;
    private f29?;
    private g29;
    private uiManager;
    private h29;
    private constructor();
    static getInstance(context: Context, k45: TokenResultListener): PhoneNumberAuthHelper;
    setAuthSDKInfo(j45: string): void;
    setAuthConfig(config: AuthUiConfig): void;
    quitPrivacyAlert(): void;
    quitLoginPage(): Promise<void>;
    accelerateLoginPage(h45: number, listener: PreLoginResultListener): void;
    getVerifyToken(g45: number): void;
    j29(timeout: number, listener: TokenResultListener, d45: s13): Promise<void>;
    registerNavigation(c45: NavPathStack): void;
    getLoginToken(totalTime: number): Promise<void>;
    l29(q44: number, requestId: string): Promise<void>;
    setDialog(p44: boolean): void;
    o29(): void;
    private k29;
    setAuthListener(k44?: TokenResultListener): void;
    clearAuthListener(): void;
    accelerateVerify(j44: number, listener: PreLoginResultListener): void;
    setUIClickListener(i44: AuthUIControlClickListener): void;
    checkEnvAvailable(type: number): void;
    getCurrentCarrierName(): Promise<string>;
    queryCheckBoxIsChecked(): boolean;
}
