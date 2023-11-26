import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

String getRFC1123() {
  DateTime dt = DateTime.now();
  dt = dt.add(Duration(milliseconds: 0 - dt.timeZoneOffset.inMilliseconds));
  return formatDate(dt, [D, ', ', dd, ' ', M, ' ', yyyy, ' ', HH, ':', nn, ':', ss, ' ', 'GMT']);
}

class WSParma {
  late final String appid;
  late final String apiKey;
  late final String secretKey;
  late final String host;
  late final String path;
  late final String sparkUrl;

  WSParma({required this.appid, required this.apiKey, required this.secretKey, required this.sparkUrl}) {
    host = Uri.parse(sparkUrl).host;
    path = Uri.parse(sparkUrl).path;
  }

  Uri createUrl() {
    // 生成RFC1123格式的时间戳
    var date = getRFC1123();

    var signatureOrigin = "host: $host\n";
    signatureOrigin += "date: $date\n";
    signatureOrigin += "GET $path HTTP/1.1";

    // 进行hmac-sha256进行加密
    var signatureSha = Hmac(sha256, utf8.encode(secretKey)).convert(utf8.encode(signatureOrigin)).toString();
    var authorizationOrigin =
        'api_key="$apiKey", algorithm="hmac-sha256", headers="host date request-line", signature="$signatureSha"';

    // authorization
    var authorization = base64.encode(utf8.encode(authorizationOrigin));

    var v = {
      "authorization": authorization,
      "date": date,
      "host": host,
    };
    var url = Uri.parse(sparkUrl).replace(queryParameters: v);
    return url;
  }
}

Map<String, dynamic> genParams(String appid, String domain, GenerateText question,
    {double temperature = 0.5, int maxTokens = 4096}) {
  var text = question.text;
  var data = {
    "header": {"app_id": appid, "uid": "1234"},
    "parameter": {
      "chat": {"domain": domain, "temperature": temperature, "max_tokens": maxTokens}
    },
    "payload": {
      "message": {"text": text}
    }
  };
  return data;
}

class SparkApiData {
  final String appid;
  final String apiKey;
  final String secretKey;
  final String sparkUrl;
  final String domain;

  SparkApiData(
      {required this.appid,
      required this.apiKey,
      required this.secretKey,
      required this.sparkUrl,
      required this.domain});

  SparkApiData.fromJson(Map<String, dynamic> json)
      : appid = json['appId'],
        apiKey = json['apiKey'],
        secretKey = json['secretKey'],
        sparkUrl = json['sparkUrl'],
        domain = json['domain'];
}

SparkApiData? readConfig(Directory dir) {
  try {
    var file = File("${dir.path}/config.json");
    String content = file.readAsStringSync();
    SparkApiData data = SparkApiData.fromJson(jsonDecode(content));

    var appid = data.appid;
    var apiKey = data.apiKey;
    var secretKey = data.secretKey;
    var sparkUrl = data.sparkUrl;
    var domain = data.domain;

    return SparkApiData(
      appid: appid,
      apiKey: apiKey,
      secretKey: secretKey,
      sparkUrl: sparkUrl,
      domain: domain,
    );
  } catch (e) {
    print(e);
    return null;
  }
}

class SparkApi {
  final GenerateText question;
  final SparkApiData sparkApiData;

  late WebSocketChannel _channel;
  Stream get stream => _channel.stream;

  bool status = false;
  String _content = "";

  SparkApi(this.question, this.sparkApiData) {
    if (question.text.isEmpty) {
      status = false;
      return;
    } else {
      status = true;
      var ws = WSParma(
        appid: sparkApiData.appid,
        apiKey: sparkApiData.apiKey,
        secretKey: sparkApiData.secretKey,
        sparkUrl: sparkApiData.sparkUrl,
      );
      var url = ws.createUrl();
      _channel = WebSocketChannel.connect(url);
      _channel.sink.add(jsonEncode(genParams(sparkApiData.appid, sparkApiData.domain, question)));
    }
  }

  (int, String) parseParams(Map<String, dynamic> data) {
    var code = data['header']['code'];
    if (code != 0) {
      _channel.sink.close();
      debugPrint(data.toString());
      _channel.sink.close();
      return (-1, data.toString());
    } else {
      //
      var choices = data['payload']['choices'];
      int status = choices["status"];
      String content = choices["text"][0]["content"].replaceAll("\n\n", "\n");
      if (status == 0) {
        _content = content;
      } else if (status >= 1) {
        _content += content;
        if (status == 2) {
          _channel.sink.close();
        }
      }
      return (status, _content);
    }
  }
}

class GenerateText {
  final List<Map<String, String>> texts = [];
  List<Map<String, String>> get text => texts;

  void addText(String role, String content) {
    texts.add({"role": role, "content": content});
  }

  int getLength() {
    int len = 0;
    for (var item in texts) {
      len += item.toString().length;
    }
    return len;
  }

  void checkLen() {
    while (getLength() > 8000) {
      texts.removeAt(0);
    }
  }
}
