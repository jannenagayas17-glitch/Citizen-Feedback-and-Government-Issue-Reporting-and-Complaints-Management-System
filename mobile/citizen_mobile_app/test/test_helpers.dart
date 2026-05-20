import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<int> _transparentImageBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0xC9,
  0xFE,
  0x92,
  0xEF,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

ByteData _byteDataFromBytes(List<int> bytes) {
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

ByteData _jsonByteData(String value) {
  return _byteDataFromBytes(utf8.encode(value));
}

final ByteData _emptyAssetManifest = const StandardMessageCodec().encodeMessage(
  <String, Object?>{},
)!;

void setupWidgetTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final String key = const StringCodec().decodeMessage(message)!;
    if (key == 'AssetManifest.bin') {
      return _emptyAssetManifest;
    }
    if (key == 'AssetManifest.json') {
      return _jsonByteData('{}');
    }
    if (key == 'FontManifest.json') {
      return _jsonByteData('[]');
    }
    if (key == 'NOTICES.Z') {
      return ByteData(0);
    }
    if (key.endsWith('.svg')) {
      final svg = utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"></svg>',
      );
      return _byteDataFromBytes(svg);
    }
    return _byteDataFromBytes(_transparentImageBytes);
  });
}

void configureTestViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1440, 2200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void resetMockPreferences([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
}
