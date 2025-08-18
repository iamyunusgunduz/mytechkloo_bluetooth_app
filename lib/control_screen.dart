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

  // Komut etiketlerini ve komut stringlerini bir Map'te tutalım.
  final Map<String, String> _commands = {
    'Temizle': '[c]',
    'Manuel': '[m]',
    'Fan': '[f]',
    'LED': '[L]',
    'Otomatik': '[o]',
    'Zaman': '[t]',
  };

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
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onPressed,
    bool isHighlighted = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isHighlighted ? color.shade400 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: isHighlighted ? Colors.white : color.shade700,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isHighlighted ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Başlık ve Kedi İkonu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kedi Tuvaleti',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6A1B9A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MiyavBox Pro',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.pets,
                    size: 48,
                    color: Colors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Zaman Ayarı ve Mutluluk Kartları
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.purple, size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Zaman Ayarı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('05:00', style: TextStyle(fontSize: 20)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.sentiment_very_satisfied, color: Colors.pink, size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Mutluluk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('85%', style: TextStyle(fontSize: 20)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Kum Seviyesi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kum Seviyesi',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '75%',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.75,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Simüle Et',
                        style: TextStyle(color: Colors.blue[600]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Komut Butonları (Grid)
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                  children: [
                    _buildCommandButton(
                      label: 'Temizle',
                      icon: Icons.cleaning_services,
                      color: Colors.cyan,
                      onPressed: () => _sendCommand(_commands['Temizle']!),
                    ),
                    _buildCommandButton(
                      label: 'Manuel',
                      icon: Icons.sports_esports,
                      color: Colors.deepOrange,
                      onPressed: () => _sendCommand(_commands['Manuel']!),
                    ),
                    _buildCommandButton(
                      label: 'Fan',
                      icon: Icons.wind_power,
                      color: Colors.lightGreen,
                      onPressed: () => _sendCommand(_commands['Fan']!),
                    ),
                    _buildCommandButton(
                      label: 'LED',
                      icon: Icons.lightbulb,
                      color: Colors.amber,
                      onPressed: () => _sendCommand(_commands['LED']!),
                    ),
                    _buildCommandButton(
                      label: 'Otomatik',
                      icon: Icons.auto_mode,
                      color: Colors.deepPurple,
                      onPressed: () => _sendCommand(_commands['Otomatik']!),
                      isHighlighted: true,
                    ),
                    _buildCommandButton(
                      label: 'Zaman',
                      icon: Icons.access_time,
                      color: Colors.red,
                      onPressed: _showTimerDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Alt Durum Çubuğu
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // En alt mesaj
              Text(
                'Kediniz mutlu, siz mutlu :)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
