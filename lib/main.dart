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
  static const String deviceName = 'ESP32-EGG-PAM';

  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  bool scanning = false;
  bool connected = false;

  StreamSubscription<List<ScanResult>>? scanSubscription;

  Future<void> scanDevice() async {
    setState(() {
      scanning = true;
    });

    try {
      await FlutterBluePlus.stopScan();

      scanSubscription?.cancel();

      scanSubscription =
          FlutterBluePlus.onScanResults.listen((results) async {
        for (final result in results) {
          final name = result.device.platformName;

          if (name == deviceName) {
            await FlutterBluePlus.stopScan();

            device = result.device;

            try {
              await device!.connect();

              final services = await device!.discoverServices();

              for (final service in services) {
                for (final c in service.characteristics) {
                  if (c.properties.write ||
                      c.properties.writeWithoutResponse) {
                    characteristic = c;
                    break;
                  }
                }

                if (characteristic != null) {
                  break;
                }
              }

              if (characteristic != null) {
                setState(() {
                  connected = true;
                });
              }
            } catch (e) {
              debugPrint('Connect error: $e');
            }

            break;
          }
        }
      });

      await FlutterBluePlus.startScan(
        withNames: [deviceName],
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Scan error: $e');
    } finally {
      if (mounted) {
        setState(() {
          scanning = false;
        });
      }
    }
  }

  Future<void> sendCommand(String command) async {
    if (!connected || characteristic == null) {
      return;
    }

    try {
      await characteristic!.write(
        command.codeUnits,
        withoutResponse: false,
      );
    } catch (e) {
      debugPrint('Send error: $e');
    }
  }

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
          color: connected ? Colors.blue : Colors.grey,
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

  @override
  void dispose() {
    scanSubscription?.cancel();
    device?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 EGG PAM'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Text(
              connected ? 'เชื่อมต่อแล้ว' : 'ยังไม่ได้เชื่อมต่อ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: connected ? Colors.green : Colors.red,
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: scanning ? null : scanDevice,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(
                scanning ? 'กำลังค้นหา...' : 'ค้นหา ESP32',
              ),
            ),

            const SizedBox(height: 40),

            controlButton(
              icon: Icons.arrow_upward,
              command: 'F',
              size: 90,
            ),

            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                controlButton(
                  icon: Icons.arrow_back,
                  command: 'L',
                  size: 90,
                ),

                const SizedBox(width: 20),

                GestureDetector(
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
                ),

                const SizedBox(width: 20),

                controlButton(
                  icon: Icons.arrow_forward,
                  command: 'R',
                  size: 90,
                ),
              ],
            ),

            const SizedBox(height: 15),

            controlButton(
              icon: Icons.arrow_downward,
              command: 'B',
              size: 90,
            ),

            const SizedBox(height: 30),

            const Text(
              'F = เดินหน้า   B = ถอยหลัง',
              style: TextStyle(fontSize: 15),
            ),

            const Text(
              'L = ซ้าย   R = ขวา   S = หยุด',
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
