import common from '@ohos.app.ability.common';
import cameraPicker from '@ohos.multimedia.cameraPicker';
import camera from '@ohos.multimedia.camera';
import filePicker from '@ohos.file.picker';
import fileFs from '@ohos.file.fs';
import hilog from '@ohos.hilog';
import notificationManager from '@ohos.notificationManager';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import AbilityAware from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityAware';
import { AbilityPluginBinding } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/ability/AbilityPluginBinding';

const CHANNEL = 'hospital/media_permission';

interface MediaFileResult {
  name: string;
  path: string;
  size: number;
}

export default class MediaPermissionPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;

  getUniqueClassName(): string { return 'MediaPermissionPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler(this);
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }
  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context as common.UIAbilityContext;
  }
  onDetachedFromAbility(): void { this.context = null; }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    void this.handle(call, result);
  }

  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (this.context == null) {
        result.error('MEDIA_CONTEXT_UNAVAILABLE', 'Ability context is unavailable.', null);
        return;
      }
      switch (call.method) {
        case 'capturePhoto':
          hilog.info(0x0000, 'MediaPlugin', 'capturePhoto begin');
          result.success(await this.capturePhoto());
          hilog.info(0x0000, 'MediaPlugin', 'capturePhoto replied');
          return;
        case 'pickFiles':
          hilog.info(0x0000, 'MediaPlugin', 'pickFiles begin');
          result.success(await this.pickFiles());
          hilog.info(0x0000, 'MediaPlugin', 'pickFiles replied');
          return;
        case 'notificationEnabled':
          result.success(await notificationManager.isNotificationEnabled());
          return;
        case 'requestNotification':
          await notificationManager.requestEnableNotification(this.context);
          result.success(await notificationManager.isNotificationEnabled());
          return;
        case 'openNotificationSettings':
          await notificationManager.openNotificationSettings(this.context);
          result.success(null);
          return;
        case 'log': {
          const args = call.args as Map<string, string>;
          hilog.info(0x0000, 'MediaPlugin', 'Dart: %{public}s', `${args?.get('message') ?? ''}`);
          result.success(null);
          return;
        }
        default:
          result.notImplemented();
      }
    } catch (error) {
      result.error('MEDIA_OPERATION_FAILED', `${error}`, null);
    }
  }

  private async capturePhoto(): Promise<MediaFileResult> {
    // PickerProfile is a value object on HarmonyOS. Do not instantiate it and
    // assign fields afterwards: recent system versions expose those fields as
    // read-only at runtime and throw a TypeError.
    const profile: cameraPicker.PickerProfile = {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
    };
    const picked = await cameraPicker.pick(this.context!, [cameraPicker.PickerMediaType.PHOTO], profile);
    return this.copyToCache(picked.resultUri, 'photo.jpg');
  }

  private async pickFiles(): Promise<Array<MediaFileResult>> {
    const picker = new filePicker.DocumentViewPicker(this.context!);
    const options = new filePicker.DocumentSelectOptions();
    options.fileSuffixFilters = ['.pdf', '.png', '.jpg', '.jpeg', '.webp'];
    options.maxSelectNumber = 10;
    const uris = await picker.select(options);
    hilog.info(0x0000, 'MediaPlugin', 'pickFiles selected %{public}d uris', uris.length);
    const files: Array<MediaFileResult> = [];
    for (const uri of uris) {
      hilog.info(0x0000, 'MediaPlugin', 'pickFiles copying %{public}s', uri);
      files.push(await this.copyToCache(uri, this.fileName(uri)));
      hilog.info(0x0000, 'MediaPlugin', 'pickFiles copy ok, count=%{public}d', files.length);
    }
    return files;
  }

  // Multi-MB payloads sent through the platform channel are silently dropped
  // by the OHOS Flutter engine (the Dart side never resolves), so copy each
  // picked file into the app sandbox and only return { name, path, size }.
  private async copyToCache(uri: string, fallbackName: string): Promise<MediaFileResult> {
    hilog.info(0x0000, 'MediaPlugin', 'copyToCache begin uri=%{public}s', uri);
    const source = await fileFs.open(uri, fileFs.OpenMode.READ_ONLY);
    try {
      const info = await fileFs.stat(source.fd);
      const size = Number(info.size);
      hilog.info(0x0000, 'MediaPlugin', 'copyToCache stat size=%{public}d', size);
      const buffer = new ArrayBuffer(size);
      let offset = 0;
      while (offset < size) {
        const read = await fileFs.read(source.fd, buffer, {
          length: size - offset,
        });
        if (read <= 0) {
          break;
        }
        offset += read;
      }
      const output = offset === size ? buffer : buffer.slice(0, offset);
      const destPath = `${this.context!.cacheDir}/chat_${Date.now()}_${fallbackName}`;
      const dest = await fileFs.open(
        destPath,
        fileFs.OpenMode.READ_WRITE | fileFs.OpenMode.CREATE | fileFs.OpenMode.TRUNC,
      );
      try {
        await fileFs.write(dest.fd, output);
      } finally {
        await fileFs.close(dest.fd);
      }
      hilog.info(0x0000, 'MediaPlugin', 'copyToCache done path=%{public}s size=%{public}d', destPath, offset);
      return { name: fallbackName, path: destPath, size: offset };
    } finally {
      await fileFs.close(source.fd);
      hilog.info(0x0000, 'MediaPlugin', 'copyToCache source closed');
    }
  }

  private fileName(uri: string): string {
    const value = uri.split('/').pop() ?? '';
    return value.length > 0 ? value : 'attachment';
  }
}
