import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';

class QuickChipsWidget extends StatelessWidget {
  final ValueChanged<int> onAddAmount;
  final VoidCallback onTakeRemainingQuota;
  final int sisaJatahHariIni;

  const QuickChipsWidget({
    Key? key,
    required this.onAddAmount,
    required this.onTakeRemainingQuota,
    required this.sisaJatahHariIni,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildAddChip(context, 1000, '+1.000'),
              const SizedBox(width: 6),
              _buildAddChip(context, 2000, '+2.000'),
              const SizedBox(width: 6),
              _buildAddChip(context, 3000, '+3.000'),
              const SizedBox(width: 6),
              _buildAddChip(context, 5000, '+5.000'),
              const SizedBox(width: 6),
              _buildAddChip(context, 10000, '+10.000'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Tombol Ambil Sisa Jatah Hari Ini
        if (sisaJatahHariIni > 0)
          InkWell(
            onTap: onTakeRemainingQuota,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade400, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 4),
                  Text(
                    'Ambil Sisa Jatah Hari Ini (${CurrencyFormatter.format(sisaJatahHariIni)})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade950,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddChip(BuildContext context, int amount, String label) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF00796B),
      ),
      backgroundColor: const Color(0xFFE0F2F1),
      side: BorderSide(color: Colors.teal.shade200),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () => onAddAmount(amount),
    );
  }
}
