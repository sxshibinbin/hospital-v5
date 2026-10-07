
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import AliAuthPlugin from '../plugins/AliAuthPlugin';
import SystemUrlPlugin from '../plugins/SystemUrlPlugin';
import AppPersistencePlugin from '../plugins/AppPersistencePlugin';
import QrScannerPlugin from '../plugins/QrScannerPlugin';
import MediaPermissionPlugin from '../plugins/MediaPermissionPlugin';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    flutterEngine.getPlugins()?.add(new AliAuthPlugin())
    flutterEngine.getPlugins()?.add(new SystemUrlPlugin())
    flutterEngine.getPlugins()?.add(new AppPersistencePlugin())
    flutterEngine.getPlugins()?.add(new QrScannerPlugin())
    flutterEngine.getPlugins()?.add(new MediaPermissionPlugin())
  }
}
