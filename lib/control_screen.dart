import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ControlScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic writeCharacteristic;

  const ControlScreen({
    super.key,
    required this.device,
    required this.writeCharacteristic,
  });

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  String _status = 'Bağlantı başarılı, komut göndermeye hazır.';
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  Future<void> _sendCommand(String command) async {
    try {
      await widget.writeCharacteristic.write(command.codeUnits, withoutResponse: false);
      if (mounted) {
        setState(() => _status = 'Komut gönderildi: $command');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Komut gönderilemedi: ${e.toString()}');
      }
    }
  }

  void _showTimerDialog() {
    _minutesController.clear();
    _secondsController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Zaman Ayarı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Dakika (xx)'),
              ),
              TextField(
                controller: _secondsController,
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
                final minutes = (_minutesController.text.isEmpty)
                    ? '00'
                    : _minutesController.text.padLeft(2, '0');
                final seconds = (_secondsController.text.isEmpty)
                    ? '00'
                    : _secondsController.text.padLeft(2, '0');
                final command = '[t=$minutes:$seconds]';
                _sendCommand(command);
                Navigator.of(context).pop();
              },
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommandButton({
    required String label,
    required String imagePath,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            height: 96,
            width: 96,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName.isEmpty
            ? 'Cihaz Kontrolü'
            : widget.device.platformName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFAB47BC),
              Color(0xFF8E24AA),
              Color(0xFF6A1B9A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
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
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 16
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildCommandButton(
                        label: 'Automatik',
                        imagePath: 'lib/images/leftright.png',
                        onPressed: () => _sendCommand('[o]'),
                      ),
                      _buildCommandButton(
                        label: 'Manuel',
                        imagePath: 'lib/images/right.png',
                        onPressed: () => _sendCommand('[m]'),
                      ),
                      _buildCommandButton(
                        label: 'Clean',
                        imagePath: 'lib/images/exit.png',
                        onPressed: () => _sendCommand('[c]'),
                      ),
                      _buildCommandButton(
                        label: 'Fan',
                        imagePath: 'lib/images/fan.png',
                        onPressed: () => _sendCommand('[f]'),
                      ),
                      _buildCommandButton(
                        label: 'Timer',
                        imagePath: 'lib/images/time.png',
                        onPressed: _showTimerDialog,
                      ),
                      _buildCommandButton(
                        label: 'LED',
                        imagePath: 'lib/images/light.png',
                        onPressed: () => _sendCommand('[L]'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
