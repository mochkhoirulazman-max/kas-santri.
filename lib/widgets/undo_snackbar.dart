import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../utils/currency_formatter.dart';

class UndoToastHelper {
  static Timer? _dismissTimer;

  static void showPostWithdrawal({
    required ScaffoldMessengerState messenger,
    required KasSantriProvider provider,
    required String message,
    required double bottomMargin,
    bool isWarning = false,
  }) {
    _dismissTimer?.cancel();
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isWarning
                ? const Color(0xFFFB7185).withOpacity(0.6)
                : const Color(0xFF34D399).withOpacity(0.45),
          ),
        ),
        backgroundColor:
            isWarning ? const Color(0xFF881337) : const Color(0xFF0F172A),
        content: Row(
          children: [
            Icon(
              isWarning ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: isWarning ? const Color(0xFFFDE68A) : const Color(0xFF34D399),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () async {
                _dismissTimer?.cancel();
                messenger.hideCurrentSnackBar();
                await provider.undoLastTransaction();
                _showAutoDismissInfo(
                  messenger: messenger,
                  message: 'Transaksi dibatalkan & saldo dikembalikan.',
                  bottomMargin: bottomMargin,
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withOpacity(0.55),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                _dismissTimer?.cancel();
                provider.dismissUndo();
                messenger.hideCurrentSnackBar();
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: Colors.white54, size: 16),
              ),
            ),
          ],
        ),
      ),
    );

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      messenger.hideCurrentSnackBar();
    });
  }

  static void _showAutoDismissInfo({
    required ScaffoldMessengerState messenger,
    required String message,
    required double bottomMargin,
  }) {
    _dismissTimer?.cancel();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFFF59E0B),
        content: Text(
          message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF030712),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      messenger.hideCurrentSnackBar();
    });
  }
}

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
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final bottomMargin = MediaQuery.of(context).padding.bottom + 84;
                  await provider.undoLastTransaction();
                  UndoToastHelper._showAutoDismissInfo(
                    messenger: messenger,
                    message: 'Transaksi berhasil dibatalkan dan saldo dikembalikan.',
                    bottomMargin: bottomMargin,
                  );
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
