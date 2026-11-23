import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/santri.dart';
import '../providers/kas_santri_provider.dart';
import '../utils/app_feedback.dart';

class QuickEditSantriBottomSheet extends StatefulWidget {
  final Santri santri;

  const QuickEditSantriBottomSheet({Key? key, required this.santri}) : super(key: key);

  static Future<void> show(BuildContext context, Santri santri) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickEditSantriBottomSheet(santri: santri),
    );
  }

  @override
  State<QuickEditSantriBottomSheet> createState() => _QuickEditSantriBottomSheetState();
}

class _QuickEditSantriBottomSheetState extends State<QuickEditSantriBottomSheet> {
  late TextEditingController _namaLengkapController;
  late TextEditingController _namaPanggilanController;
  late TextEditingController _kamarController;
  late TextEditingController _noWaWaliController;
  late TextEditingController _jatahHarianController;

  String? _fotoPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.santri;
    _namaLengkapController = TextEditingController(text: s.namaLengkap);
    _namaPanggilanController = TextEditingController(text: s.namaPanggilan);
    _kamarController = TextEditingController(text: s.kamar);
    _noWaWaliController = TextEditingController(text: s.noWaWali ?? '');
    _jatahHarianController = TextEditingController(text: s.jatahHarian.toString());
    _fotoPath = s.fotoPath;
  }

  @override
  void dispose() {
    _namaLengkapController.dispose();
    _namaPanggilanController.dispose();
    _kamarController.dispose();
    _noWaWaliController.dispose();
    _jatahHarianController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    AppFeedback.tap();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'webp'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _fotoPath = result.files.single.path!;
        });
      }
    } catch (_) {}
  }

  void _removePhoto() {
    AppFeedback.tap();
    setState(() {
      _fotoPath = null;
    });
  }

  Future<void> _save() async {
    final nama = _namaLengkapController.text.trim();
    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama lengkap wajib diisi!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    AppFeedback.success();

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final jatah = int.tryParse(_jatahHarianController.text.trim()) ?? widget.santri.jatahHarian;

    final updated = widget.santri.copyWith(
      namaLengkap: nama,
      namaPanggilan: _namaPanggilanController.text.trim().isNotEmpty
          ? _namaPanggilanController.text.trim()
          : (nama.split(' ').isNotEmpty ? nama.split(' ').first : nama),
      kamar: _kamarController.text.trim().isNotEmpty ? _kamarController.text.trim() : widget.santri.kamar,
      noWaWali: _noWaWaliController.text.trim().isNotEmpty ? _noWaWaliController.text.trim() : null,
      jatahHarian: jatah,
      fotoPath: _fotoPath,
    );

    await provider.saveSantri(updated, isEdit: true);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data ${updated.namaLengkap} berhasil diperbarui!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.santri;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF070B14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF06B6D4), width: 1.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Judul
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('✏️', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text(
                      'Edit Data & Foto Santri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 16),

            // Avatar & Tombol Ubah Foto
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF06B6D4), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF06B6D4).withOpacity(0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _fotoPath != null && File(_fotoPath!).existsSync()
                              ? Image.file(File(_fotoPath!), fit: BoxFit.cover)
                              : Container(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  alignment: Alignment.center,
                                  child: Text(
                                    s.namaPanggilan.isNotEmpty
                                        ? s.namaPanggilan.substring(0, 1).toUpperCase()
                                        : 'S',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      PositionDirectional(
                        bottom: 0,
                        end: 0,
                        child: InkWell(
                          onTap: _pickPhoto,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF06B6D4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.black, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('Ganti Foto', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                        onPressed: _pickPhoto,
                      ),
                      if (_fotoPath != null) ...[
                        const SizedBox(width: 6),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFFB7185)),
                          label: const Text('Hapus', style: TextStyle(color: Color(0xFFFB7185), fontSize: 11)),
                          onPressed: _removePhoto,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Form Fields
            _buildField('NAMA LENGKAP', _namaLengkapController, 'Nama lengkap santri...'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildField('NAMA PANGGILAN', _namaPanggilanController, 'Contoh: Ahmad')),
                const SizedBox(width: 10),
                Expanded(child: _buildField('KAMAR / ASRAMA', _kamarController, 'Contoh: Kamar 1')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildField('NO WHATSAPP WALI (OPSIONAL)', _noWaWaliController, '08xxxxxxxxxx', isPhone: true),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildField('JATAH/HARI (RP)', _jatahHarianController, '10000', isNumber: true),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('SIMPAN PERUBAHAN', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: const Color(0xFF030712),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                onPressed: _isLoading ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {bool isNumber = false, bool isPhone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumber || isPhone ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 11.5),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 1.5)),
          ),
        ),
      ],
    );
  }
}
