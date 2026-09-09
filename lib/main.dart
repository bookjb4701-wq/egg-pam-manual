import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const EggPamApp());
}

class EggPamApp extends StatelessWidget {
  const EggPamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ESP32 EGG PAM',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ==============================
  // ESP32
  // ==============================
  static const String deviceName = 'ESP32-EGG-PAM';

  static const String serviceUuid =
      '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

  static const String characteristicUuid =
      '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

  // ==============================
  // BLE
  // ==============================
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  bool scanning = false;
  bool connected = false;

  // ==============================
  // ค้นหา ESP32
  // ==============================
  Future<void> scanDevice() async {
    if (scanning) return;

    setState(() {
      scanning = true;
    });

    try {
      await FlutterBluePlus.stopScan();

      await scanSubscription?.cancel();

      scanSubscription =
          FlutterBluePlus.onScanResults.listen((results) async {
        for (final result in results) {
          final name = result.device.platformName;

          if (name == deviceName) {
            await FlutterBluePlus.stopScan();

            device = result.device;

            try {
              // ==================================
              // จุดที่แก้ปัญหา license
              // ==================================
              await device!.connect(
                license: License.nonprofit,
              );

              // ==================================
              // ตรวจสอบสถานะการเชื่อมต่อ
              // ==================================
              connectionSubscription?.cancel();

              connectionSubscription =
                  device!.connectionState.listen((state) {
                if (!mounted) return;

                setState(() {
                  connected =
                      state == BluetoothConnectionState.connected;
                });
              });

              // ==================================
              // ค้นหา Service
              // ==================================
              final services =
                  await device!.discoverServices();

              BluetoothCharacteristic? foundCharacteristic;

              for (final service in services) {
                // ตรวจ Service UUID
                if (service.uuid.toString().toUpperCase() ==
                    serviceUuid.toUpperCase()) {
                  for (final c in service.characteristics) {
                    // ตรวจ Characteristic UUID
                    if (c.uuid.toString().toUpperCase() ==
                        characteristicUuid.toUpperCase()) {
                      foundCharacteristic = c;
                      break;
                    }
                  }
                }

                if (foundCharacteristic != null) {
                  break;
                }
              }

              if (foundCharacteristic != null) {
                characteristic = foundCharacteristic;

                if (mounted) {
                  setState(() {
                    connected = true;
                  });
                }
              } else {
                if (mounted) {
                  setState(() {
                    connected = false;
                  });
                }

                debugPrint(
                  'ไม่พบ Characteristic ของ ESP32',
                );
              }
            } catch (e) {
              debugPrint(
                'Connect error: $e',
              );

              if (mounted) {
                setState(() {
                  connected = false;
                });
              }
            }

            break;
          }
        }
      });

      // ==================================
      // เริ่ม Scan
      // ==================================
      await FlutterBluePlus.startScan(
        withNames: [deviceName],
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint(
        'Scan error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          scanning = false;
        });
      }
    }
  }

  // ==============================
  // ส่งคำสั่งไป ESP32
  // ==============================
  Future<void> sendCommand(String command) async {
    if (!connected || characteristic == null) {
      return;
    }

    try {
      await characteristic!.write(
        command.codeUnits,
        withoutResponse: false,
      );

      debugPrint(
        'ส่งคำสั่ง: $command',
      );
    } catch (e) {
      debugPrint(
        'Send error: $e',
      );
    }
  }

  // ==============================
  // ปุ่มควบคุม
  // ==============================
  Widget controlButton({
    required IconData icon,
    required String command,
    required double size,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        sendCommand(command);
      },
      onTapUp: (_) {
        sendCommand('S');
      },
      onTapCancel: () {
        sendCommand('S');
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: connected
              ? Colors.blue
              : Colors.grey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.45,
        ),
      ),
    );
  }

  // ==============================
  // ปุ่มหยุด
  // ==============================
  Widget stopButton() {
    return GestureDetector(
      onTap: () {
        sendCommand('S');
      },
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.stop,
          color: Colors.white,
          size: 45,
        ),
      ),
    );
  }

  // ==============================
  // ปิด App
  // ==============================
  @override
  void dispose() {
    scanSubscription?.cancel();
    connectionSubscription?.cancel();
    device?.disconnect();

    super.dispose();
  }

  // ==============================
  // หน้าหลัก
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ESP32 EGG PAM',
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ==============================
            // สถานะ
            // ==============================
            Text(
              connected
                  ? 'เชื่อมต่อ ESP32 แล้ว'
                  : 'ยังไม่ได้เชื่อมต่อ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: connected
                    ? Colors.green
                    : Colors.red,
              ),
            ),

            const SizedBox(height: 15),

            // ==============================
            // ปุ่มค้นหา
            // ==============================
            ElevatedButton.icon(
              onPressed:
                  scanning ? null : scanDevice,
              icon: const Icon(
                Icons.bluetooth_searching,
              ),
              label: Text(
                scanning
                    ? 'กำลังค้นหา...'
                    : 'ค้นหา ESP32',
              ),
            ),

            const SizedBox(height: 40),

            // ==============================
            // เดินหน้า F
            // ==============================
            controlButton(
              icon: Icons.arrow_upward,
              command: 'F',
              size: 90,
            ),

            const SizedBox(height: 15),

            // ==============================
            // ซ้าย / หยุด / ขวา
            // ==============================
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                // ซ้าย L
                controlButton(
                  icon: Icons.arrow_back,
                  command: 'L',
                  size: 90,
                ),

                const SizedBox(width: 20),

                // หยุด S
                stopButton(),

                const SizedBox(width: 20),

                // ขวา R
                controlButton(
                  icon: Icons.arrow_forward,
                  command: 'R',
                  size: 90,
                ),
              ],
            ),

            const SizedBox(height: 15),

            // ==============================
            // ถอยหลัง B
            // ==============================
            controlButton(
              icon: Icons.arrow_downward,
              command: 'B',
              size: 90,
            ),

            const SizedBox(height: 30),

            // ==============================
            // คำอธิบาย
            // ==============================
            const Text(
              'F = เดินหน้า    B = ถอยหลัง',
              style: TextStyle(
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'L = ซ้าย    R = ขวา    S = หยุด',
              style: TextStyle(
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
