import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const String deviceName = 'ESP32-EGG-PAM';

const String serviceUuid =
    '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

const String characteristicUuid =
    '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

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
      home: const ControllerPage(),
    );
  }
}

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  bool scanning = false;
  bool connected = false;

  String status = 'ยังไม่ได้เชื่อมต่อ';

  @override
  void dispose() {
    scanSubscription?.cancel();
    connectionSubscription?.cancel();

    if (device != null) {
      device!.disconnect();
    }

    super.dispose();
  }

  // ==============================
  // ค้นหา ESP32
  // ==============================

  Future<void> scanAndConnect() async {
    if (scanning) return;

    setState(() {
      scanning = true;
      status = 'กำลังค้นหา ESP32-EGG-PAM...';
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

            await connectToDevice();

            return;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
      );

      await Future.delayed(
        const Duration(seconds: 9),
      );

      if (!connected && mounted) {
        setState(() {
          status = 'ไม่พบ ESP32-EGG-PAM';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          status = 'เกิดข้อผิดพลาด: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          scanning = false;
        });
      }
    }
  }

  // ==============================
  // เชื่อมต่อ ESP32
  // ==============================

  Future<void> connectToDevice() async {
    if (device == null) return;

    try {
      setState(() {
        status = 'กำลังเชื่อมต่อ...';
      });

      await connectionSubscription?.cancel();

      connectionSubscription =
          device!.connectionState.listen((state) {
        if (!mounted) return;

        setState(() {
          connected =
              state == BluetoothConnectionState.connected;

          if (connected) {
            status = 'เชื่อมต่อ ESP32 แล้ว';
          } else {
            status = 'ตัดการเชื่อมต่อ';
            characteristic = null;
          }
        });
      });

      await device!.connect(
        timeout: const Duration(seconds: 10),
      );

      final services =
          await device!.discoverServices();

      for (final service in services) {
        if (service.uuid.toString().toUpperCase() ==
            serviceUuid.toUpperCase()) {
          for (final c in service.characteristics) {
            if (c.uuid.toString().toUpperCase() ==
                characteristicUuid.toUpperCase()) {
              characteristic = c;

              if (mounted) {
                setState(() {
                  connected = true;
                  status =
                      'ESP32-EGG-PAM เชื่อมต่อแล้ว';
                });
              }

              return;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          status = 'ไม่พบ Characteristic';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          connected = false;
          status = 'เชื่อมต่อไม่ได้';
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
        utf8.encode(command),
        withoutResponse: false,
      );

      debugPrint('ส่งคำสั่ง: $command');
    } catch (e) {
      debugPrint('ส่งคำสั่งไม่สำเร็จ: $e');
    }
  }

  // ==============================
  // ปุ่มควบคุม
  // ==============================

  Widget controlButton({
    required String text,
    required String command,
    required IconData icon,
    double size = 80,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTapDown: (_) {
          sendCommand(command);
        },
        onTapUp: (_) {
          sendCommand('S');
        },
        onTapCancel: () {
          sendCommand('S');
        },
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================
  // ปุ่มหยุดฉุกเฉิน
  // ==============================

  Widget emergencyButton() {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton.icon(
        onPressed: () {
          sendCommand('S');
        },
        icon: const Icon(
          Icons.warning,
          size: 30,
        ),
        label: const Text(
          'EMERGENCY STOP',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==============================
  // หน้าจอ
  // ==============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 EGG PAM'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // สถานะ Bluetooth
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        size: 35,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          status,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // ปุ่มค้นหา
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      scanning ? null : scanAndConnect,
                  icon: Icon(
                    scanning
                        ? Icons.search
                        : Icons.bluetooth_searching,
                  ),
                  label: Text(
                    scanning
                        ? 'กำลังค้นหา...'
                        : 'ค้นหา ESP32-EGG-PAM',
                  ),
                ),
              ),

              const Spacer(),

              // เดินหน้า
              controlButton(
                text: 'เดินหน้า',
                command: 'F',
                icon: Icons.keyboard_arrow_up,
              ),

              const SizedBox(height: 15),

              // ซ้าย STOP ขวา
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  controlButton(
                    text: 'ซ้าย',
                    command: 'L',
                    icon: Icons.keyboard_arrow_left,
                  ),

                  controlButton(
                    text: 'STOP',
                    command: 'S',
                    icon: Icons.stop,
                  ),

                  controlButton(
                    text: 'ขวา',
                    command: 'R',
                    icon: Icons.keyboard_arrow_right,
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ถอยหลัง
              controlButton(
                text: 'ถอยหลัง',
                command: 'B',
                icon: Icons.keyboard_arrow_down,
              ),

              const Spacer(),

              // Emergency Stop
              emergencyButton(),
            ],
          ),
        ),
      ),
    );
  }
}
