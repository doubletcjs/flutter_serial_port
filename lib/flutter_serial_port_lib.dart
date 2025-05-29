import 'package:flutter/services.dart';

class FlutterSerialPort {
  static const MethodChannel _methodChannel = MethodChannel('com.samstudio.flutter_serial_port_lib');
  static const EventChannel _eventChannel = EventChannel("com.samstudio.flutter_serial_port_lib/event");

  static Stream receiveStream() {
    return _eventChannel.receiveBroadcastStream().map((dynamic value) {
      return value;
    });
  }

  static Future<String> get platformVersion async {
    final String version = await _methodChannel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// List all devices
  static Future<List<Device>> listDevices() async {
    List devices = await _methodChannel.invokeMethod("getAllDevices");
    List devicesPath = await _methodChannel.invokeMethod("getAllDevicesPath");

    List<Device> deviceList = [];
    devices.asMap().forEach((index, deviceName) {
      deviceList.add(Device(deviceName, devicesPath[index]));
    });
    return deviceList;
  }

  /// Create an [SerialPort] instance
  static Future<SerialPort> createSerialPort(
    Device device,
    int baudRate, {
    int parity = 0,
    int dataBits = 8,
    int stopBit = 1,
  }) async {
    return SerialPort(
      device: device,
      baudRate: baudRate,
      parity: parity,
      dataBits: dataBits,
      stopBit: stopBit,
      isConnected: false,
    );
  }
}

class SerialPort {
  Device device;
  int baudRate = 9600;
  int parity = 0;
  int dataBits = 8;
  int stopBit = 1;
  bool isConnected = false;

  late MethodChannel _methodChannel;

  SerialPort({
    required this.device,
    required this.baudRate,
    required this.parity,
    required this.dataBits,
    required this.stopBit,
    required this.isConnected,
  }) {
    _methodChannel = FlutterSerialPort._methodChannel;
  }

  @override
  String toString() {
    return "SerialPort($device, $baudRate, $parity, $dataBits, $stopBit)";
  }

  /// Open device
  Future<bool> open() async {
    bool openResult = await _methodChannel.invokeMethod("open", {
      'devicePath': device.path,
      'baudRate': baudRate,
      'parity': parity,
      'dataBits': dataBits,
      'stopBit': stopBit,
    });

    if (openResult) {
      isConnected = true;
    }

    return openResult;
  }

  /// Close device
  Future<bool> close() async {
    bool closeResult = await _methodChannel.invokeMethod("close", {
      'devicePath': device.path,
    });

    if (closeResult) {
      isConnected = false;
    }

    return closeResult;
  }

  /// Write data to device
  Future<bool> write(Uint8List data) async {
    return await _methodChannel.invokeMethod("write", {
      'devicePath': device.path,
      "data": data,
    });
  }
}

/// [Device] contains device information(name and path).
class Device {
  String name;
  String path;

  Device(this.name, this.path);

  @override
  String toString() {
    return "Device($name, $path)";
  }
}
