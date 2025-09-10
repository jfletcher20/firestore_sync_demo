import 'package:device_info_plus/device_info_plus.dart';
import 'package:swan_sync/presentation/screens/item_list_screen.dart';
import 'package:swan_sync/communications/platforms_data_mixin.dart';
import 'package:swan_sync/communications/core/service_locator.dart';
import 'package:swan_sync/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> with PlatformsDataMixin {
  @override
  void initState() {
    super.initState();
    ServiceLocator().setup();
    // put additional setup logic here, such as user authentication
    // for now, initPlatformState retrieves device identifier to identify the user instead
    initPlatformState();
  }

  static final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

  Future<void> initPlatformState() async {
    var deviceData = <String, dynamic>{};

    try {
      if (kIsWeb) {
        deviceData = readWebBrowserInfo(await deviceInfoPlugin.webBrowserInfo);
      } else {
        deviceData = switch (defaultTargetPlatform) {
          TargetPlatform.android => readAndroidBuildData(await deviceInfoPlugin.androidInfo),
          TargetPlatform.iOS => readIosDeviceInfo(await deviceInfoPlugin.iosInfo),
          TargetPlatform.linux => readLinuxDeviceInfo(await deviceInfoPlugin.linuxInfo),
          TargetPlatform.windows => readWindowsDeviceInfo(await deviceInfoPlugin.windowsInfo),
          TargetPlatform.macOS => readMacOsDeviceInfo(await deviceInfoPlugin.macOsInfo),
          TargetPlatform.fuchsia => <String, dynamic>{
            'Error:': 'Fuchsia platform isn\'t supported',
          },
        };
      }
    } on PlatformException {
      deviceData = <String, dynamic>{'Error:': 'Failed to get platform version.'};
    }

    MainApp.deviceName = deviceData['name'] ?? 'anonymous swan';
  }

  @override
  Widget build(BuildContext context) {
    // when user auth is implemented, check auth state here and display appropriate screen
    // for now, we directly go to the ItemListScreen
    // initPlatformState is considered fast enough to not require a loading screen
    return const ItemListScreen();
  }
}
