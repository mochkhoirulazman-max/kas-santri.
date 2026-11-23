import 'package:flutter/material.dart';
import '../../models/santri.dart';
import '../../utils/currency_formatter.dart';

class EmergencyOverrideDialog extends StatefulWidget {
  final Santri santri;
  final Function(int newQuota) onQuotaChanged;

  const EmergencyOverrideDialog({
    Key? key,
    required this.santri,
    required this.onQuotaChanged,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required Santri santri,
    required Function(int newQuota) onQuotaChanged,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => EmergencyOverrideDialog(
        santri: santri,
        onQuotaChanged: onQuotaChanged,
      ),
    );
  }

  @override
  State<EmergencyOverrideDialog> createState() =>
      _EmergencyOverrideDialogState();
}

class _EmergencyOverrideDialogState extends State<EmergencyOverrideDialog> {
  late TextEditingController _quotaController;

  @override
  void initState() {
    super.initState();
    _quotaController = TextEditingController(
      text: widget.santri.jatahHarian.toString(),
    );
  }

  @override
  void dispose() {
    _quotaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.tune, color: Color(0xFF00796B)),
          SizedBox(width: 8),
          Text(
            'Penyesuaian Kuota',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Atur batas kuota harian khusus santri ${widget.santri.namaLengkap}:',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quotaController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Jatah Harian (Rp)',
              prefixText: 'Rp ',
              helperText: 'Default pondok: Rp 10.000 / hari',
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _quotaController.clear(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [5000, 10000, 15000, 20000].map((preset) {
              return ActionChip(
                label: Text(CurrencyFormatter.format(preset)),
                onPressed: () {
                  setState(() {
                    _quotaController.text = preset.toString();
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            final val = int.tryParse(_quotaController.text) ?? widget.santri.jatahHarian;
            if (val <= 0) return;
            widget.onQuotaChanged(val);
            Navigator.pop(context);
          },
          child: const Text('Simpan Perubahan'),
        ),
      ],
    );
  }
}
