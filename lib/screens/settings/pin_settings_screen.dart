import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../database/database_helper.dart';

class PinSettingsScreen extends StatefulWidget {
  const PinSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PinSettingsScreen> createState() => _PinSettingsScreenState();
}

class _PinSettingsScreenState extends State<PinSettingsScreen> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _hasExistingPin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final settings = await DatabaseHelper.instance.getPengaturan();
    setState(() {
      _hasExistingPin = settings.pinKeamanan != null && settings.pinKeamanan!.isNotEmpty;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (_hasExistingPin) {
      final oldValid = await AuthService.instance.verifyPin(_oldPinController.text);
      if (!oldValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN lama salah!'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final newPin = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (newPin.length < 4 || newPin.length > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN harus terdiri dari 4 sampai 6 digit angka')),
      );
      return;
    }

    if (newPin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi PIN tidak cocok!')),
      );
      return;
    }

    await AuthService.instance.setPin(newPin);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kunci PIN berhasil diperbarui!'),
          backgroundColor: Color(0xFF00796B),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _removePin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kunci PIN?'),
        content: const Text('Aplikasi tidak akan terkunci lagi saat dibuka.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus PIN'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.instance.setPin(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunci PIN berhasil dinonaktifkan')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_hasExistingPin ? 'Ganti PIN Pengurus' : 'Pasang Kunci PIN'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.security, color: Color(0xFF00796B)),
                      SizedBox(width: 8),
                      Text(
                        'Keamanan Aplikasi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kunci PIN menjaga agar santri tidak dapat mengubah saldo ketika HP pengurus tergeletak.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(height: 24),

                  if (_hasExistingPin) ...[
                    TextField(
                      controller: _oldPinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Masukkan PIN Lama',
                        prefixIcon: Icon(Icons.lock_open),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _newPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'PIN Baru (4-6 Digit)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _confirmPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Ulangi PIN Baru',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _savePin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Simpan Kunci PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),

                  if (_hasExistingPin) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _removePin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Nonaktifkan Kunci PIN'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
