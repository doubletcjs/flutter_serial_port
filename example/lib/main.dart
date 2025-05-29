import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'serial_port_model.dart';
import 'serial_port_utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final RxList<Map> _datas = List<Map>.from([]).obs;

  @override
  void initState() {
    super.initState();

    SerialPortUtils.openAll().then((value) {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Obx(() {
          RxList<SerialPortModel> serialPortList = List<SerialPortModel>.from(SerialPortUtils.serialPortList).obs;
          serialPortList.removeWhere((element) => element.address == -1);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...SerialPortUtils.serialPortList.map((serial) {
                  return Text(
                    serial.toJson().toString(),
                    style: const TextStyle(color: Colors.black),
                  );
                }),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(serialPortList.length, (index) => index).map((index) {
                    if (SerialPortUtils.readerEventData["port"] == serialPortList[index].path) {
                      Map map = {};
                      map["onEvent"] = SerialPortUtils.readerEventData["onEvent"];
                      map["onEventData"] = SerialPortUtils.readerEventData["onEventData"];
                      if (_datas.length < index || _datas.isEmpty) {
                        _datas.add(map);
                      } else {
                        _datas[index] = map;
                      }
                    }

                    Map data = _datas.length < index ? {} : _datas[index];

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: index == 0 ? 0 : 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "port: ${serialPortList[index].path}",
                              style: const TextStyle(color: Colors.black),
                            ),
                            const SizedBox(height: 5),
                            if (data.containsKey("onEvent"))
                              Text(
                                "onEvent: ${data["onEvent"]}",
                                style: const TextStyle(color: Colors.black),
                              ),
                            const SizedBox(height: 5),
                            if (data.containsKey("onEventData"))
                              Text(
                                "onEventData: ${data["onEventData"]}",
                                style: const TextStyle(color: Colors.black),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
