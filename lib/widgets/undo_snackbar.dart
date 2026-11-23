import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../utils/currency_formatter.dart';

class UndoBottomBanner extends StatelessWidget {
  const UndoBottomBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<KasSantriProvider>(
      builder: (context, provider, child) {
        if (!provider.canUndo) return const SizedBox.shrink();

        final santri = provider.lastSantri;
        final tx = provider.lastTransaction;
        if (santri == null || tx == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF263238),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF80CBC4), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Berhasil Ambil ${CurrencyFormatter.format(tx.nominal)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Sisa saldo ${santri.namaPanggilan}: ${CurrencyFormatter.format(santri.saldoTotal)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Tombol Undo dengan Countdown
              ElevatedButton(
                onPressed: () async {
                  await provider.undoLastTransaction();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaksi berhasil dibatalkan dan saldo dikembalikan.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  'BATAL (${provider.undoCountdown}s)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                onPressed: () => provider.dismissUndo(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }
}
