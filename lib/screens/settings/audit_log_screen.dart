import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/audit_log.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/app_feedback.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/app_background_wrapper.dart';
import '../paywall_screen.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({Key? key}) : super(key: key);

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _loading = true;
  List<AuditLogEntry> _entries = const [];
  AuditLogVerificationResult? _verification;
  String _selectedFilter = 'SEMUA';

  static const List<({String code, String label})> _filters = [
    (code: 'SEMUA', label: 'Semua'),
    (code: 'VOID_TRANSAKSI', label: 'Void'),
    (code: 'EDIT_TRANSAKSI', label: 'Edit Transaksi'),
    (code: 'HAPUS_SANTRI', label: 'Hapus Santri'),
    (code: 'SERAH_TERIMA_INFAK', label: 'Serah Infak'),
    (code: 'RESTORE_BACKUP', label: 'Restore'),
    (code: 'RESET_DATA', label: 'Reset'),
    (code: 'UBAH_PENGATURAN', label: 'Pengaturan'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAudit();
  }

  Future<void> _loadAudit() async {
    setState(() => _loading = true);
    try {
      final verification = await DatabaseHelper.instance.verifyAuditLogIntegrity();
      final logs = await DatabaseHelper.instance.getAuditLogs(
        limit: 300,
        actionFilter: _selectedFilter == 'SEMUA' ? null : _selectedFilter,
      );
      if (mounted) {
        setState(() {
          _verification = verification;
          _entries = logs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color _accentForAction(String action) {
    if (action.contains('VOID') || action.contains('HAPUS') || action.contains('RESET')) {
      return const Color(0xFFF43F5E);
    }
    if (action.contains('RESTORE') || action.contains('PIN') || action.contains('PRIVASI')) {
      return const Color(0xFFFBBF24);
    }
    if (action.contains('LISENSI') || action.contains('SERAH_TERIMA')) {
      return const Color(0xFF34D399);
    }
    return const Color(0xFF38BDF8);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    if (!provider.hasProAccess) {
      return AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Jejak Audit Keamanan 🔒')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(22),
                borderColor: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🛡️ 👑', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 10),
                    const Text(
                      'Jejak Audit Anti-Curang (PRO)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fitur log keamanan rantai hash SHA-256 tersedia eksklusif pada Kas-Santri PRO atau selama masa Uji Coba Gratis 14 Hari.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => PaywallScreen.show(
                        context,
                        triggerFeature: 'Jejak Audit Keamanan Anti-Curang (Hash-Chain)',
                      ),
                      icon: const Text('👑'),
                      label: const Text('Buka Kas-Santri PRO / Trial 14 Hari'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final verif = _verification;
    final chainOk = verif?.isValid ?? true;

    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Jejak Audit Keamanan'),
          actions: [
            IconButton(
              tooltip: 'Verifikasi Ulang Rantai Audit',
              onPressed: () {
                AppFeedback.tap();
                _loadAudit();
              },
              icon: const Icon(Icons.verified_user_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(14),
                borderColor: chainOk
                    ? const Color(0xFF34D399).withOpacity(0.45)
                    : const Color(0xFFF43F5E).withOpacity(0.7),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (chainOk
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF43F5E))
                            .withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        chainOk ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                        color: chainOk
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFDA4AF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chainOk
                                ? 'Rantai Audit SHA-256 Utuh (Read-Only)'
                                : 'Peringatan Integritas Audit!',
                            style: TextStyle(
                              color: chainOk
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFFFDA4AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            verif?.message ??
                                'Memeriksa rantai hash kriptografi catatan aktivitas...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final f = _filters[idx];
                  final active = _selectedFilter == f.code;
                  return ChoiceChip(
                    label: Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: active ? const Color(0xFF04121A) : Colors.white70,
                      ),
                    ),
                    selected: active,
                    selectedColor: const Color(0xFF34D399),
                    backgroundColor: Colors.black26,
                    side: BorderSide(
                      color: active ? const Color(0xFF34D399) : Colors.white12,
                    ),
                    onSelected: (_) {
                      AppFeedback.tap();
                      setState(() => _selectedFilter = f.code);
                      _loadAudit();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Belum ada aktivitas sensitif yang tercatat untuk filter ini.\n\nCatatan audit bersifat permanen (INSERT-only) dan tidak dapat dihapus.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 12.5),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = _entries[idx];
                            final accent = _accentForAction(item.action);
                            final dt = DateTime.tryParse(item.createdAt);
                            final tsLabel = dt != null
                                ? DateFormatter.formatFullDateTime(dt)
                                : item.createdAt;
                            final shortHash = item.entryHash.length >= 12
                                ? item.entryHash.substring(0, 12)
                                : item.entryHash;
                            return GlassCard(
                              borderRadius: 18,
                              padding: const EdgeInsets.all(12),
                              borderColor: accent.withOpacity(0.32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accent.withOpacity(0.16),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: accent.withOpacity(0.45),
                                          ),
                                        ),
                                        child: Text(
                                          item.action,
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        tsLabel,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.summary,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline_rounded,
                                        size: 13,
                                        color: Colors.white54,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.actor,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Hash: $shortHash…',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 9.5,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
