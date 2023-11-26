import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_window_utils/window_manipulator.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import 'spark.dart';
import 'windows.dart';

var configPath = getApplicationDocumentsDirectory();
SparkApiData? defaultConfig;

void main() async {
  // 测试接口
  // 判断是否为macOS
  initWindowsSize();

  runApp(const OKToast(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class ClipExplain {
  String clipContent;
  String explain;
  DateTime time;
  ClipExplain(this.clipContent, this.explain, this.time);
}

class _MyHomePageState extends State<MyHomePage> {
  late Timer timer;

  bool state = false;
  bool topSwitch = true;
  double fontsize = 12.5;
  String _clipContent = "";
  String _answer = "【复制文字以开始】";

  final TextEditingController _controller = TextEditingController();

  _handleKeyPress(RawKeyEvent event) {
    final bool isCtrlPressed = event.isControlPressed;
    final bool isCKeyPressed = event.logicalKey == LogicalKeyboardKey.keyS;
    if (isCtrlPressed && isCKeyPressed) {
      _copy();
    }
  }

  _copy() {
    if (state == false && _answer != "【复制文字以开始】") {
      Clipboard.setData(ClipboardData(text: _answer));
      showToast("已复制到剪贴板");
    } else {
      showToast("正在生成中");
    }
  }

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(_handleKeyPress);

    Clipboard.getData(Clipboard.kTextPlain).then((value) => _clipContent = value?.text ?? "");
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      ClipboardData? clipdata = await Clipboard.getData(Clipboard.kTextPlain);
      if (state == false &&
          clipdata != null &&
          clipdata.text != _clipContent &&
          clipdata.text != "" &&
          clipdata.text != _answer) {
        if (defaultConfig == null) {
          //
          defaultConfig = readConfig((await configPath));
          showToast("请先配置: ${(await configPath).path}/config.json");
          return;
        }
        // 请求AI接口
        debugPrint(clipdata.text!);
        _clipContent = clipdata.text!;
        _controller.text = _clipContent;
        var sparkApi = SparkApi(GenerateText()..addText('user', _clipContent), defaultConfig!);
        sparkApi.stream.listen((event) {
          var data = jsonDecode(event);
          var (status, ans) = sparkApi.parseParams(data);
          if (status == 0) {
            if (Platform.isMacOS) {
              WindowManipulator.setDocumentEdited();
            }
            state = true;
          } else if (status == 1) {
            _answer += ans;
          } else if (status == 2) {
            if (Platform.isMacOS) {
              WindowManipulator.setDocumentUnedited();
            }
            state = false;
          }
          setState(() {
            _answer = ans;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SizedBox.expand(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            child: CupertinoTextField(
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              style: TextStyle(fontSize: fontsize, fontFamily: "HarmonyOS"),
            ),
          ),
          Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: SelectableText(_answer, style: TextStyle(fontSize: fontsize, fontFamily: "HarmonyOS")))),
              )),
          const Divider(),
          SizedBox(
            height: 40,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Switch(
                value: topSwitch,
                onChanged: (bool value) {
                  if (value == true) {
                    windowAlwaysOnTop(true);
                    showToast("置顶模式");
                  } else {
                    windowAlwaysOnTop(false);
                    showToast("非置顶模式");
                  }
                  setState(() {
                    topSwitch = value;
                  });
                },
              ),
              TextButton(
                onPressed: () async {
                  showToast((await configPath).path);
                },
                child: const Text("Spark AI built by @qi-xmu",
                    // 斜体 透明度 紫色
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: "HarmonyOS",
                      color: Color.fromRGBO(0, 0, 0, 0.5),
                    )),
              ),
              TextButton(
                onPressed: () => _copy(),
                child: const Text("复制", style: TextStyle(fontFamily: "HarmonyOS")),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
