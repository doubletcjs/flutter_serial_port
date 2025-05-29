class SerialPortModel {
  String name = "";
  String path = "";
  bool open = false;
  int address = -1;
  SerialConfigModel config = SerialConfigModel.fromJson({});
  SerialPortModel({
    required this.name,
    required this.open,
    required this.config,
    required this.address,
  });

  SerialPortModel.fromJson(Map<String, dynamic> json)
      : name = json["name"] ?? "",
        path = json["path"] ?? "",
        address = json["address"] ?? -1,
        open = json["open"] ?? false,
        config = SerialConfigModel.fromJson(json["config"] ?? {});

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "open": open,
      "address": address,
      "path": path,
      "config": config.toJson(),
    };
  }
}

class SerialConfigModel {
  int baudRate = 115200;
  int bits = 8;
  int stopBits = 1;
  int parity = 0;

  SerialConfigModel({
    required this.baudRate,
    required this.bits,
    required this.stopBits,
    required this.parity,
  });

  SerialConfigModel.fromJson(Map<String, dynamic> json)
      : baudRate = json["baudRate"] ?? 115200,
        bits = json["bits"] ?? 8,
        stopBits = json["stopBits"] ?? 1,
        parity = json["parity"] ?? 0;

  Map<String, dynamic> toJson() {
    return {
      "baudRate": baudRate,
      "bits": bits,
      "stopBits": stopBits,
      "parity": parity,
    };
  }
}

List<int> bitsMap = [8, 7, 6, 5];
List<int> stopBitsMap = [1, 2];
List<String> parityMap = ["None(无)", "Odd(奇)", "Even(偶)"];
List<int> baudRateMap = [300, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 74880, 115200, 230400];
