import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_feedback.dart';

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
    final hasPin = await AuthService.instance.hasPin();
    if (mounted) {
      setState(() {
        _hasExistingPin = hasPin;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    AppFeedback.tap();
    if (_hasExistingPin) {
      final oldValid = await AuthService.instance.verifyPin(_oldPinController.text.trim());
      if (!oldValid) {
        AppFeedback.alert();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN lama salah!'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    final newPin = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (!AuthService.isValidPinFormat(newPin)) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN harus terdiri dari 4 sampai 6 digit angka (0–9)'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    if (newPin != confirm) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfirmasi PIN tidak cocok!'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
      return;
    }

    await AuthService.instance.setPin(newPin);
    await AuthService.instance.updateLastActive();
    if (mounted) {
      await Provider.of<KasSantriProvider>(context, listen: false).loadAllData();
      AppFeedback.success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kunci PIN aman berhasil diperbarui!'),
          backgroundColor: Color(0xFF10B981),
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
        await Provider.of<KasSantriProvider>(context, listen: false).loadAllData();
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
      backgroundColor: const Color(0xFF060A12),
      appBar: AppBar(
        title: Text(_hasExistingPin ? 'Ganti PIN Pengurus' : 'Pasang Kunci PIN'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.security, color: Color(0xFF34D399)),
                      SizedBox(width: 8),
                      Text(
                        'Keamanan Aplikasi (PIN 4–6 Digit)',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kunci PIN menjaga agar santri tidak dapat mengubah saldo ketika HP pengurus tergeletak.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const Divider(height: 24, color: Colors.white12),

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
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF030712),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Simpan Kunci PIN', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),

                  if (_hasExistingPin) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _removePin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFB7185),
                        side: const BorderSide(color: Color(0xFFF43F5E)),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Nonaktifkan Kunci PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
