import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_serial_port_lib/flutter_serial_port_lib.dart';

void main() {
  const MethodChannel channel = MethodChannel('com.samstudio.flutter_serial_port_lib');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMethodCallHandler((call) => Future(() => 42));
  });

  tearDown(() {
    channel.setMethodCallHandler((call) => Future(() => null));
  });

  test('getPlatformVersion', () async {
    expect(await FlutterSerialPort.platformVersion, '42');
  });
}
