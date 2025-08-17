import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  // FlutterBluePlus'ın loglarını kapatarak konsolu temiz tutar.
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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
  BluetoothCharacteristic? _writeCharacteristic;
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
    // Uygulama başlar başlamaz Bluetooth durumunu dinlemeye başla
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _adapterState = state;
          if (state == BluetoothAdapterState.on) {
            _status = 'Bluetooth aktif. Taramaya hazır.';
          } else {
            // Bluetooth kapanırsa, taramayı durdur ve bağlantıyı sıfırla
            _isScanning = false;
            FlutterBluePlus.stopScan();
            _connectedDevice = null;
            _writeCharacteristic = null;
            _status = 'Bluetooth kapalı. Lütfen açın.';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // Sayfadan çıkıldığında tüm dinleyicileri iptal et
    _scanResultsSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _disconnect(); // Uygulama kapanırken bağlantıyı kes
    super.dispose();
  }

  // Gerekli izinleri kontrol et ve iste
  Future<void> _checkPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // Bluetooth'u aç/kapat (sadece Android)
  Future<void> _toggleBluetooth() async {
    if (Platform.isAndroid) {
      if (_adapterState == BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOff();
      } else {
        await FlutterBluePlus.turnOn();
      }
    }
  }

  // Cihazları tara
  Future<void> _scanDevices() async {
    // Bluetooth kapalıysa veya zaten taranıyorsa işlemi başlatma
    if (_adapterState != BluetoothAdapterState.on || _isScanning) return;

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

    // Tarama durduğunda state'i güncelle
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    setState(() {
      _isScanning = false;
      _status = 'Tarama tamamlandı. ${_scanResults.length} cihaz bulundu.';
    });
  }

  // Taramayı durdur
  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  // Seçilen cihaza bağlan
  Future<void> _connectToDevice(ScanResult result) async {
    final device = result.device;
    setState(() {
      _status = '${device.platformName} cihazına bağlanılıyor...';
    });

    // Bağlantı durumu değişikliklerini (örneğin kopmaları) dinle
    _connectionStateSubscription =
        device.connectionState.listen((BluetoothConnectionState state) {
      if (state == BluetoothConnectionState.disconnected) {
        if (mounted) {
          setState(() {
            _connectedDevice = null;
            _writeCharacteristic = null;
            _status = 'Bağlantı kesildi. Tekrar bağlanın.';
          });
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
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            _writeCharacteristic = characteristic;
            break;
          }
        }
        if (_writeCharacteristic != null) break;
      }

      if (_writeCharacteristic != null) {
        setState(() {
          _status = '${device.platformName} bağlandı ve komuta hazır.';
        });
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

  // Bağlantıyı kes
  Future<void> _disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      // dinleyici zaten state'i güncelleyeceği için burada tekrar setState yapmaya gerek yok.
    }
  }

  // Cihaza komut gönder
  Future<void> _sendCommand(String command) async {
    // Bağlantı ve karakteristik kontrolü
    if (_connectedDevice == null || _writeCharacteristic == null) {
      setState(() => _status = 'Bağlantı yok veya komut kanalı bulunamadı.');
      return;
    }
    try {
      // Cihaz 'Write without Response' desteklemediği için bu parametreyi
      // 'false' yapıyoruz. Bu, komutun gönderildiğine dair onay bekler.
      await _writeCharacteristic!.write(command.codeUnits, withoutResponse: false);
      
      setState(() => _status = 'Komut gönderildi: $command');
    } catch (e) {
      setState(() => _status = 'Komut gönderilemedi: ${e.toString()}');
    }
  }

  // Zaman ayarı için dialog penceresi
  void _showTimePickerDialog() {
    final minutesController = TextEditingController();
    final secondsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Zaman Ayarı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Dakika (xx)'),
              ),
              TextField(
                controller: secondsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Saniye (zz)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final minutes = (minutesController.text.isEmpty)
                    ? '00'
                    : minutesController.text.padLeft(2, '0');
                final seconds = (secondsController.text.isEmpty)
                    ? '00'
                    : secondsController.text.padLeft(2, '0');
                final command = '[t=$minutes:$seconds]';
                _sendCommand(command);
                Navigator.of(context).pop();
              },
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    ).then((_) {
      minutesController.dispose();
      secondsController.dispose();
    });
  }

  // Komut butonu oluşturan yardımcı fonksiyon
  Widget _buildCommandButton(
      {required String label, required IconData icon, required String command, VoidCallback? onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      // Sadece bağlıyken butona basılmasına izin ver
      onPressed: _connectedDevice != null ? (onPressed ?? () => _sendCommand(command)) : null,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isBtOn = _adapterState == BluetoothAdapterState.on;
    bool isConnected = _connectedDevice != null;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyTechKloo'),
        leading: Platform.isAndroid
            ? IconButton(
                icon: Icon(
                  isBtOn ? Icons.bluetooth_disabled : Icons.bluetooth,
                  color: isBtOn ? Colors.blue : Colors.grey,
                ),
                onPressed: _toggleBluetooth,
              )
            : null,
        actions: [
          TextButton.icon(
            icon: Icon(_isScanning ? Icons.stop_circle_outlined : Icons.search),
            label: Text(_isScanning ? 'DURDUR' : 'TARA'),
            // Sadece Bluetooth açıksa taramaya izin ver
            onPressed: isBtOn ? (_isScanning ? _stopScan : _scanDevices) : null,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green.shade100 : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8)
              ),
              child: Text(_status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isConnected ? Colors.green.shade900 : Colors.orange.shade900
                  )),
            ),
            const SizedBox(height: 10),
            const Divider(height: 20),
            Expanded(
              child: _scanResults.isEmpty
                  ? Center(child: Text(isBtOn ? 'Cihazları bulmak için TARA butonuna basın.' : 'Cihazları listelemek için Bluetooth\'u açın.'))
                  : ListView.builder(
                      itemCount: _scanResults.length,
                      itemBuilder: (context, index) {
                        ScanResult result = _scanResults[index];
                        BluetoothDevice device = result.device;
                        
                        // RSSI değerine göre ikon seçimi
                        IconData signalIcon;
                        if (result.rssi > -60) {
                          signalIcon = Icons.signal_wifi_4_bar; // Güçlü sinyal
                        } else if (result.rssi > -80) {
                          signalIcon = Icons.signal_wifi_4_bar; // Orta sinyal
                        } else {
                          signalIcon = Icons.signal_wifi_0_bar; // Zayıf sinyal
                        }

                        return Card(
                          color: _connectedDevice?.remoteId == device.remoteId ? Colors.indigo.withOpacity(0.1) : null,
                          child: ListTile(
                            title: Text(device.platformName.isEmpty
                                ? 'Bilinmeyen Cihaz'
                                : device.platformName),
                            subtitle: Text('${device.remoteId} (RSSI: ${result.rssi})'),
                            trailing: _connectedDevice?.remoteId == device.remoteId
                                ? const Icon(Icons.bluetooth_connected, color: Colors.green)
                                : Icon(signalIcon, color: Colors.blue),
                            onTap: () => _connectToDevice(result),
                          ),
                        );
                      },
                    ),
            ),
            if (isConnected) ...[
              const Divider(height: 20),
              Text(
                'Kontrol Paneli',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  _buildCommandButton(label: 'Clean', icon: Icons.cleaning_services, command: '[c]'),
                  _buildCommandButton(label: 'Manuel', icon: Icons.pan_tool, command: '[m]'),
                  _buildCommandButton(label: 'Fan', icon: Icons.air, command: '[f]'),
                  _buildCommandButton(label: 'LED', icon: Icons.lightbulb_outline, command: '[L]'),
                  _buildCommandButton(label: 'Otomatik', icon: Icons.settings_power, command: '[o]'),
                  _buildCommandButton(
                    label: 'Zaman Ayarı',
                    icon: Icons.timer,
                    command: '', 
                    onPressed: _showTimePickerDialog,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.link_off),
                label: const Text('Bağlantıyı Kes'),
                onPressed: _disconnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}