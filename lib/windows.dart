import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:macos_window_utils/macos/ns_window_level.dart';
import 'package:macos_window_utils/window_manipulator.dart';
import 'package:window_manager/window_manager.dart';

void windowAlwaysOnTop(bool state) async {
  if (Platform.isMacOS) {
    await WindowManipulator.setLevel(NSWindowLevel.floating);
  } else if (Platform.isWindows || Platform.isLinux) {
    await windowManager.setAlwaysOnTop(state);
  }
}

void initWindowsSize() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    await WindowManipulator.initialize(enableWindowDelegate: true);
    await WindowManipulator.setLevel(NSWindowLevel.floating);
    await WindowManipulator.makeTitlebarTransparent();
    // 设置窗口大小
    await WindowManipulator.setWindowFrame(const Rect.fromLTWH(0, 500, 400, 400));
  } else if (Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(400, 400),
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setTitle("Spark AI Tools");
      await windowManager.show();
    });
  }
}
