import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import 'spark.dart';
import 'windows.dart';

var configPath = getApplicationDocumentsDirectory();
SparkApiData? defaultConfig;

var setting = {
  "fontSize": 13.0,
};

void main() async {
  // 测试接口
  // 判断是否为macOS
  initWindowsSize();
  defaultConfig = readConfig((await configPath));

  runApp(const OKToast(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(color: Colors.black, fontSize: setting["fontSize"], fontFamily: "HarmonyOS"),
        ),
      ),
      home: const MyHomePage(),
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
  bool topSwitch = true;

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      child: SizedBox.expand(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: AnswerList()),
        ]),
      ),
    );
  }
}

class AnswerList extends StatefulWidget {
  const AnswerList({super.key});

  @override
  State<AnswerList> createState() => _AnswerListState();
}

class _AnswerListState extends State<AnswerList> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final answerList = <String>["> 复制以开始"].obs; // 答案
  final selectedIndex = <int>[].obs;
  late Timer timer;

  late String _clipContent; // 剪贴板内容
  bool genState = false;
  bool topSwitch = true;
  var editMode = false.obs;
  bool startState = true;
  bool selfCopy = false;

  void _keyBoardCtrlEnter() {
    _controller.text = _controller.text.trim();
    _focusNode.unfocus();
    _editModeSend();
  }

  void _keyBoardCtrlC() {
    _copyPressed();
  }

  void _setFontSize(double size) {
    setting["fontSize"] = size;
    showToast("字体大小: ${setting["fontSize"]}", position: ToastPosition.bottom);
    setState(() {});
  }

  void _keyBoardCtrlAdd() {
    _setFontSize(setting["fontSize"]! + 1.0);
  }

  void _keyBoardCtrlSub() {
    _setFontSize(setting["fontSize"]! - 1.0);
  }

  @override
  void initState() {
    super.initState();
    clipboardTask();
    RawKeyboard.instance.addListener((RawKeyEvent event) {
      if (event.isKeyPressed(LogicalKeyboardKey.enter) && event.isControlPressed) {
        _keyBoardCtrlEnter();
      } else if (event.isKeyPressed(LogicalKeyboardKey.keyC) && event.isControlPressed) {
        _keyBoardCtrlC();
      } else if (event.isKeyPressed(LogicalKeyboardKey.equal) && event.isControlPressed) {
        _keyBoardCtrlAdd();
      } else if (event.isKeyPressed(LogicalKeyboardKey.minus) && event.isControlPressed) {
        _keyBoardCtrlSub();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    timer.cancel();
  }

  // 判断是否请求
  bool isRequest(String text) {
    if (startState == false) {
      return false;
    }
    if (selfCopy || answerList.contains(text)) {
      // 复制自己的内容
      _clipContent = text;
      selfCopy = false;
      return false;
    }
    if (genState == false && text != _clipContent && text.isNotEmpty) {
      _clipContent = text;
      _controller.text = _clipContent;
      return true;
    }
    return false;
  }

  // answerList state
  void callSparkApi(GenerateText text) async {
    if (defaultConfig == null) {
      defaultConfig = readConfig((await configPath));
      showToast("请先配置: ${(await configPath).path}/config.json");
      return;
    }
    var sparkApi = SparkApi(text, defaultConfig!);
    sparkApi.stream.listen((event) {
      var data = jsonDecode(event);
      var (status, ans) = sparkApi.parseParams(data);
      answerList.value = ans.split('。\n\n').map((e) => '$e。').toList();
      answerList.last = answerList.last.substring(0, answerList.last.length - 1);
      if (status == 0) {
        genState = true;
      } else if (status == 2) {
        genState = false;
      }
    });
  }

  Future<String> getClipboardText() async {
    var data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null) {
      return "";
    }
    return data.text!;
  }

  void clipboardTask() async {
    _clipContent = await getClipboardText();
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      var content = await getClipboardText();
      if (isRequest(content)) {
        selectedIndex.clear();
        editMode.value = false;
        callSparkApi(GenerateText()..addText('user', content));
      }
    });
  }

  void _editModeSend() {
    var content = _controller.text;
    editMode.value = false;
    callSparkApi(GenerateText()..addText('user', content));
  }

  void _copyPressed() {
    String content;
    if (selectedIndex.isEmpty) {
      showToast("复制全部:OK");
      var clipData = answerList.map((element) => element).toList();
      content = clipData.join("\n");
    } else {
      showToast("复制选中:OK");
      var clipData = selectedIndex.map((element) => answerList[element]).toList();
      content = clipData.join("\n");
    }
    selfCopy = true;
    Clipboard.setData(ClipboardData(text: content));
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CupertinoTextField(
        controller: _controller,
        focusNode: _focusNode,
        minLines: 3,
        maxLines: 5,
        placeholder: "编辑模式...",
        suffix: Obx(() => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: editMode.value ? 60 : 0,
              child: editMode.value
                  ? TextButton(
                      onPressed: () => _editModeSend(),
                      child: Text(
                        "发送",
                        style: TextStyle(fontSize: setting['fontSize'], fontFamily: "HarmonyOS"),
                      ),
                    )
                  : const SizedBox(),
            )),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(0),
        ),
        onChanged: (String? value) {
          editMode.value = !(value == null || value.isEmpty);
        },
        style: TextStyle(height: 1.2, fontSize: setting['fontSize'], fontFamily: "HarmonyOS"),
      ),
      const Divider(),
      Expanded(
        child: AnswerBox(
          answer: answerList,
          selectedIndex: selectedIndex,
        ),
      ),
      const Divider(),
      SizedBox(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Switch(
            value: topSwitch,
            onChanged: (bool value) {
              windowAlwaysOnTop(value);
              showToast(value ? "置顶模式" : "非置顶模式");
              setState(() {
                topSwitch = value;
              });
            },
          ),
          TextButton(
            onPressed: () {
              setState(() {
                startState = !startState;
              });
              if (startState) {
                showToast("已启用");
              } else {
                showToast("已禁用");
              }
            },
            child: Text(
              startState ? "💜 已启用 💜" : "Spark AI built by @qi-xmu\nVersion: 2023-12-01(102)",
              style: const TextStyle(fontSize: 11, fontFamily: "HarmonyOS"),
            ),
          ),
          TextButton(
            onPressed: () => _copyPressed(),
            child: const Text("复制", style: TextStyle(fontFamily: "HarmonyOS")),
          )
        ]),
      ),
    ]);
  }
}

class AnswerBox extends StatelessWidget {
  final List<String> answer;
  final RxList<int> selectedIndex;
  const AnswerBox({super.key, required this.answer, required this.selectedIndex});

  _handleTap(int index) {
    debugPrint("onTap: $selectedIndex");
    if (selectedIndex.contains(index)) {
      selectedIndex.remove(index);
    } else {
      selectedIndex.add(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ListView.builder(
        scrollDirection: Axis.vertical,
        itemCount: answer.length,
        itemBuilder: (context, index) => GestureDetector(
          child: Obx(
            () => LineCard(
              key: ValueKey(answer[index]),
              index: index,
              line: answer[index],
              selected: selectedIndex.contains(index),
            ),
          ),
          onTap: () => _handleTap(index),
        ),
      ),
    );
  }
}

class LineCard extends StatelessWidget {
  final int index;
  final String line;
  final bool selected;
  const LineCard({super.key, required this.index, required this.line, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: selected ? Colors.deepPurple[50] : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? Colors.deepPurple[300]! : Colors.deepPurple[50]!, width: 3),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Markdown(
        data: line,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8.0),
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(fontSize: setting["fontSize"], fontFamily: "HarmonyOS"),
          codeblockPadding: const EdgeInsets.all(6.0),
          code: TextStyle(
            fontSize: setting["fontSize"],
            backgroundColor: Colors.transparent,
            fontFamily: "CodeMono",
          ),
          listIndent: 22,
          blockSpacing: 4,
          codeblockDecoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.deepPurple[50]!, width: 1),
            borderRadius: BorderRadius.circular(10.0),
          ),
          blockquoteDecoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.deepPurple[50]!, width: 1),
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
    );
  }
}
