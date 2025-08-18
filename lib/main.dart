import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_enable_fork/bluetooth_enable_fork.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';
import 'control_screen.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.none, color: false);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyTechKloo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BluetoothScreen(),
    );
  }
}

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  List<ScanResult> _scanResults = [];
  String _status = 'Başlamak için Bluetooth\'u açın.';
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _adapterState = state;
          if (state == BluetoothAdapterState.on) {
            _status = 'Bluetooth aktif. Taramaya hazır.';
          } else {
            _isScanning = false;
            FlutterBluePlus.stopScan();
            _connectedDevice = null;
            _status = 'Bluetooth kapalı. Lütfen açın.';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _disconnect();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _toggleBluetooth() async {
    if (_adapterState == BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOff();
      }
    } else {
      if (Platform.isAndroid) {
        try {
          String result = await BluetoothEnable.enableBluetooth;
          if (mounted) {
            if (result == "true") {
              setState(() {
                _status = 'Bluetooth başarıyla açıldı.';
              });
            } else if (result == "false") {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bluetooth açılamadı. Lütfen manuel olarak açın.')),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Bluetooth açma hatası: ${e.toString()}')),
            );
          }
        }
      } else if (Platform.isIOS) {
        // iOS'ta Bluetooth ayarlarını açmak için
        final Uri url = Uri.parse('App-prefs:root=Bluetooth');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ayarlar sayfası açılamadı.')),
            );
          }
        }
      }
    }
  }

  Future<void> _scanDevices() async {
    if (_adapterState != BluetoothAdapterState.on) {
      setState(() {
        _status = 'Lütfen önce Bluetooth\'u açın.';
      });
      return;
    }
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanResults = [];
      _status = 'Cihazlar taranıyor...';
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    setState(() {
      _isScanning = false;
      _status = 'Tarama tamamlandı. ${_scanResults.length} cihaz bulundu.';
    });
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(ScanResult result) async {
    final device = result.device;
    setState(() {
      _status = '${device.platformName} cihazına bağlanılıyor...';
    });

    _connectionStateSubscription =
        device.connectionState.listen((BluetoothConnectionState state) async {
      if (state == BluetoothConnectionState.disconnected) {
        if (mounted) {
          setState(() {
            _connectedDevice = null;
            _status = 'Bağlantı kesildi. Tekrar bağlanın.';
          });
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      }
    });

    try {
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      setState(() {
        _connectedDevice = device;
        _status = '${device.platformName} bağlandı. Servisler aranıyor...';
      });

      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? writeCharacteristic;
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            writeCharacteristic = characteristic;
            break;
          }
        }
        if (writeCharacteristic != null) break;
      }

      if (writeCharacteristic != null) {
        setState(() {
          _status = '${device.platformName} bağlandı ve komuta hazır.';
        });
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ControlScreen(
              device: device,
              writeCharacteristic: writeCharacteristic!,
            ),
          ),
        );
      } else {
        setState(() {
          _status = 'Yazma özelliği bulunamadı. Bağlantı kesiliyor.';
        });
        await device.disconnect();
      }
    } catch (e) {
      setState(() {
        _status = 'Bağlantı hatası: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
  }

  IconData _getSignalStrengthIcon(int rssi) {
    if (rssi > -60) {
      return Icons.signal_cellular_alt;
    } else if (rssi > -70) {
      return Icons.signal_cellular_alt_outlined;
    } else if (rssi > -80) {
      return Icons.signal_cellular_alt_2_bar;
    } else if (rssi > -90) {
      return Icons.signal_cellular_alt_1_bar;
    } else {
      return Icons.signal_cellular_alt_1_bar;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isBtOn = _adapterState == BluetoothAdapterState.on;
    bool isConnected = _connectedDevice != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6A1B9A), // Koyu mor
              Color(0xFF8E24AA), // Orta mor
              Color(0xFFAB47BC), // Açık mor
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBar(
                title: const Text('Bluetooth Cihazları', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Platform.isAndroid
                    ? IconButton(
                        icon: Icon(
                          isBtOn ? Icons.bluetooth_disabled : Icons.bluetooth,
                          color: Colors.white,
                        ),
                        onPressed: _toggleBluetooth,
                      )
                    : null,
                actions: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: Icon(_isScanning ? Icons.stop_circle_outlined : Icons.search),
                    label: Text(_isScanning ? 'DURDUR' : 'TARA'),
                    onPressed: isBtOn ? (_isScanning ? _stopScan : _scanDevices) : null,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green.shade100.withOpacity(0.9) : Colors.orange.shade100.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isConnected ? Colors.green.shade900 : Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 16
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _scanResults.isEmpty
                    ? Center(
                        child: Text(
                          isBtOn ? 'Cihazları bulmak için TARA butonuna basın.' : 'Cihazları listelemek için Bluetooth\'u açın.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _scanResults.length,
                        itemBuilder: (context, index) {
                          ScanResult result = _scanResults[index];
                          BluetoothDevice device = result.device;
                          IconData signalIcon = _getSignalStrengthIcon(result.rssi);

                          return Card(
                            elevation: 8,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.white.withOpacity(0.9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(
                                device.platformName.isEmpty ? 'Bilinmeyen Cihaz' : device.platformName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${device.remoteId}\nRSSI: ${result.rssi}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _connectedDevice?.remoteId == device.remoteId ? Icons.bluetooth_connected : signalIcon,
                                    color: _connectedDevice?.remoteId == device.remoteId ? Colors.green : Colors.deepPurple,
                                    size: 30,
                                  ),
                                  if (_connectedDevice?.remoteId == device.remoteId)
                                    const Text('Bağlı', style: TextStyle(color: Colors.green, fontSize: 12))
                                ],
                              ),
                              onTap: () => _connectToDevice(result),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}