import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_serial_port_lib/flutter_serial_port_lib.dart';

import 'serial_port_model.dart';

class SerialPortUtils {
  static final RxMap<String, dynamic> readerEventData = Map<String, dynamic>.from({}).obs;
  static final RxList<SerialPortModel> serialPortList = List<SerialPortModel>.from([]).obs;
  static late StreamSubscription? _serialReader;
  static final Map<String, SerialPort> _serialSender = {};
  static final Map<int, Uint8List> _lastEventRecord = {};
  static bool _skipRefreshEvent = false;
  static bool fixEventData = true;

  static Future<List<String>> availablePorts() async {
    List<Device> deviceList = await FlutterSerialPort.listDevices();
    return deviceList.map((e) => e.path).toList();
  }

  static Future<bool> available() async {
    return (await DeviceInfoPlugin().androidInfo).isPhysicalDevice && GetPlatform.isAndroid && (await availablePorts()).isNotEmpty;
  }

  static Future<bool> writePort(Uint8List data, {String? port, int? address}) async {
    Completer<bool> completer = Completer();

    if (serialPortList.isEmpty) {
      completer.complete(false);
      return completer.future;
    }

    write(SerialPortModel serialPort) async {
      if (serialPort.open && serialPort.path.isNotEmpty && _serialSender[serialPort.path] != null) {
        bool onWrite = await _serialSender[serialPort.path]!.write(data);
        debugPrint("port:${serialPort.path} send:$onWrite");
        // LogManager.setSendLogger(serialPort.path, data, onWrite > 0);
        // String cmds = uint8ListAsHexString(data);
        // debugPrint("port:${serialPort.path} send:$cmds");
        completer.complete(true);
      } else {
        completer.complete(false);
      }
    }

    SerialPortModel? serialPortModel;
    if (port != null && port.isNotEmpty) {
      serialPortModel = serialPortList.firstWhereOrNull((element) => element.path == port);
    }

    if (address != null && address > 0) {
      serialPortModel = serialPortList.firstWhereOrNull((element) => element.address == address);
    }

    if (serialPortModel == null) {
      completer.complete(false);
    } else {
      write(serialPortModel);
    }

    return completer.future;
  }

  static Future _openPort(SerialPortModel model) async {
    Completer completer = Completer();

    var serialPort = await FlutterSerialPort.createSerialPort(
      Device(model.name, model.path),
      model.config.baudRate,
      parity: model.config.parity,
      dataBits: model.config.bits,
      stopBit: model.config.stopBits,
    );

    model.open = await serialPort.open();
    if (model.open) {
      debugPrint("device:${serialPort.device.path} openResult:${model.open}");
      if (_serialSender[serialPort.device.path] == null) {
        _serialSender[serialPort.device.path] = serialPort;
      }

      serialPortList.add(model);
    }

    completer.complete(model.open);

    return completer.future;
  }

  static _setReader() {
    try {
      if (_serialReader != null) {
        _serialReader?.cancel();
        _serialReader = null;
      }
    } catch (_) {}

    _serialReader = FlutterSerialPort.receiveStream().listen((value) {
      String port = "${value['port']}";
      SerialPortModel? portModel = serialPortList.firstWhereOrNull((element) => element.path == port);
      if (portModel != null) {
        var event = value["event"];
        if (fixEventData) {
          if (_lastEventRecord.isEmpty) {
            readerEventData.value = {"onEvent": uint8ListAsHexString(event), "onEventData": event, "port": port};
          } else {
            int lastTime = _lastEventRecord.keys.toList().first;
            if (DateTime.now().microsecondsSinceEpoch - lastTime < 1000) {
              List<int> list = _lastEventRecord.values.toList().first.toList();
              list.addAll(event.toList());

              readerEventData.value = {"onEvent": uint8ListAsHexString(Uint8List.fromList(list)), "onEventData": Uint8List.fromList(list), "port": port};
              _skipRefreshEvent = true;
              Future.delayed(const Duration(microseconds: 1001), () {
                _skipRefreshEvent = false;
              });
            } else {
              Future.delayed(const Duration(microseconds: 1000), () {
                if (_skipRefreshEvent == false) {
                  readerEventData.value = {"onEvent": uint8ListAsHexString(event), "onEventData": event, "port": port};
                }
              });
            }
          }

          _lastEventRecord.clear();
          _lastEventRecord[DateTime.now().microsecondsSinceEpoch] = event;
        } else {
          readerEventData.value = {"onEvent": uint8ListAsHexString(event), "onEventData": event, "port": port};
        }

        if (event.length > 4 && event[0] == 0xA5 && event[1] == 0x5A) {
          int addressIndex = serialPortList.indexWhere((element) => element.path == port);
          if (addressIndex >= 0) {
            SerialPortModel model = serialPortList[addressIndex];
            if (model.address == -1) {
              model.address = event[4];
              serialPortList[addressIndex] = model;
              serialPortList.refresh();
            }
          }
        }

        // LogManager.setReceiveLogger(writePort.path!, event, true);
      }
    });
  }

  static Future openAll({List<String>? customPorts}) async {
    Completer completer = Completer();

    if ((await DeviceInfoPlugin().androidInfo).isPhysicalDevice && GetPlatform.isAndroid) {
      List<Device> deviceList = await FlutterSerialPort.listDevices();
      deviceList.removeWhere((element) => element.path.toUpperCase().contains("TTYS") == false);
      if (deviceList.isNotEmpty) {
        for (var i = 0; i < deviceList.length; i++) {
          Device device = deviceList[i];
          await _openPort(SerialPortModel.fromJson({})
            ..name = device.name
            ..path = device.path);
          if (i == deviceList.length - 1) {
            _setReader();
            completer.complete();
          } else {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }
    } else {
      completer.complete();
    }

    return completer.future;
  }

  static Future<bool> closePort(SerialPortModel serial) {
    Completer<bool> completer = Completer();

    if (serial.open && serial.path.isNotEmpty) {
      try {
        if (_serialSender.containsKey(serial.path)) {
          _serialSender[serial.path]!.close();
          _serialSender.remove(serial.path);
        }

        serialPortList.removeWhere((element) => element.path == serial.path);
        debugPrint("port:${serial.path} close");

        completer.complete(true);
      } catch (e) {
        debugPrint("e:$e");
        completer.complete(false);
        return completer.future;
      }
    } else {
      completer.complete(false);
    }

    return completer.future;
  }
}

/// Returns a hex string by a `Uint8List`.
String uint8ListAsHexString(Uint8List bytes, {bool unformat = false}) {
  var result = StringBuffer();
  for (var i = 0; i < bytes.lengthInBytes; i++) {
    var part = bytes[i];
    if (unformat == true) {
      result.write('${part < 16 ? '0' : ''}${part.toRadixString(16)}');
    } else {
      result.write('0x${part < 16 ? '0' : ''}${part.toRadixString(16).toUpperCase()} ');
    }
  }

  return result.toString();
}
