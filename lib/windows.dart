import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

void windowAlwaysOnTop(bool state) async {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await windowManager.setAlwaysOnTop(state);
  }
}

void initWindowsSize() async {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    WidgetsFlutterBinding.ensureInitialized();

    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(360, 600),
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setTitle("Spark AI Tools");
      await windowManager.show();
    });
  }
}
