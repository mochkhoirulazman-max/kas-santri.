import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/report_service.dart';
import '../../services/smart_wa_reminder_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_background_wrapper.dart';
import '../paywall_screen.dart';

class SmartWaReminderScreen extends StatefulWidget {
  const SmartWaReminderScreen({Key? key}) : super(key: key);

  @override
  State<SmartWaReminderScreen> createState() => _SmartWaReminderScreenState();
}

class _SmartWaReminderScreenState extends State<SmartWaReminderScreen> {
  ReminderCategory _selectedCategory = ReminderCategory.saldoKritis;
  Set<String> _sentToday = {};

  @override
  void initState() {
    super.initState();
    _loadSent();
  }

  Future<void> _loadSent() async {
    final keys = await SmartWaReminderService.instance.getSentKeysToday();
    if (mounted) {
      setState(() => _sentToday = keys);
    }
  }

  Future<void> _sendItem(
    KasSantriProvider provider,
    ReminderQueueItem item,
  ) async {
    AppFeedback.tap();
    if (!provider.isProUser) {
      await PaywallScreen.show(
        context,
        triggerFeature: 'Pusat Antrean Pengingat WA Cerdas (1-Klik Anti-Spam)',
      );
      return;
    }

    final msg = SmartWaReminderService.composePoliteMessage(
      item: item,
      namaPondok: provider.pengaturan.namaPondok,
    );
    final phone = ReportService.normalizeWaPhone(item.santri.noWaWali);
    if (phone.isEmpty) {
      AppFeedback.alert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nomor WA wali ${item.santri.namaLengkap} belum diisi.',
            ),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }
      return;
    }

    final launched = await ReportService.instance.openWhatsAppDirect(
      rawPhone: item.santri.noWaWali,
      message: msg,
    );
    if (launched) {
      final updated =
          await SmartWaReminderService.instance.markSentToday(item.uniqueKey);
      if (mounted) {
        setState(() => _sentToday = updated);
      }
    }
  }

  Future<void> _sendNextInQueue(
    KasSantriProvider provider,
    List<ReminderQueueItem> items,
  ) async {
    final pendingWithPhone = items.where((item) {
      final unsent = !_sentToday.contains(item.uniqueKey);
      final hasPhone =
          ReportService.normalizeWaPhone(item.santri.noWaWali).isNotEmpty;
      return unsent && hasPhone;
    }).toList();

    if (pendingWithPhone.isEmpty) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada antrean tersisa dengan nomor WA valid untuk kategori ini hari ini.',
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      return;
    }

    await _sendItem(provider, pendingWithPhone.first);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    if (!provider.hasProAccess) {
      return AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Pusat Pengingat Wali Santri')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  borderRadius: 26,
                  padding: const EdgeInsets.all(24),
                  borderColor: const Color(0xFFFBBF24).withValues(alpha: 0.55),
                  gradientColors: const [
                    Color(0xDE06382E),
                    Color(0xE00A1628),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔔', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFBBF24)),
                        ),
                        child: const Text(
                          '🔒 FITUR KHUSUS PRO',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pusat Antrean Pengingat WA Cerdas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kirim pesan pengingat santun 1-klik ke wali santri untuk Saldo Kritis (<3 hari), Infak Jatuh Tempo, dan Tunggakan tanpa spam.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => PaywallScreen.show(
                            context,
                            triggerFeature:
                                'Pusat Antrean Pengingat WA Cerdas (1-Klik Anti-Spam)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: const Color(0xFF030712),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                          label: const Text(
                            'Coba Gratis 14 Hari / Upgrade PRO',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final queues = SmartWaReminderService.buildPriorityQueues(
      activeSantri: provider.santriStatusList.map((e) => e.santri).toList(),
      infakPeriodeList: provider.infakPeriodeList,
    );

    final kritis = queues[ReminderCategory.saldoKritis] ?? const [];
    final infak = queues[ReminderCategory.infakJatuhTempo] ?? const [];
    final tunggakan = queues[ReminderCategory.tunggakan] ?? const [];
    final activeItems = queues[_selectedCategory] ?? const [];

    final remainingCount = activeItems.where((item) {
      return !_sentToday.contains(item.uniqueKey) &&
          ReportService.normalizeWaPhone(item.santri.noWaWali).isNotEmpty;
    }).length;

    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Pusat Pengingat Wali Santri')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      _catBtn(
                        ReminderCategory.saldoKritis,
                        'Kritis (${kritis.length})',
                        const Color(0xFFFB7185),
                      ),
                      _catBtn(
                        ReminderCategory.infakJatuhTempo,
                        'Infak (${infak.length})',
                        const Color(0xFFFBBF24),
                      ),
                      _catBtn(
                        ReminderCategory.tunggakan,
                        'Tunggakan (${tunggakan.length})',
                        const Color(0xFF38BDF8),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _sendNextInQueue(provider, activeItems),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF04121A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      provider.isProUser
                          ? 'Kirim Berikutnya via WhatsApp ($remainingCount Tersisa)'
                          : 'Kirim Berikutnya via WhatsApp 👑',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: activeItems.isEmpty
                    ? const Center(
                        child: Text(
                          'Alhamdulillah! Tidak ada antrean pengingat pada kategori ini.',
                          style: TextStyle(color: Colors.white60, fontSize: 12.5),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: activeItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final item = activeItems[idx];
                          final sent = _sentToday.contains(item.uniqueKey);
                          final hasPhone = ReportService.normalizeWaPhone(
                                  item.santri.noWaWali)
                              .isNotEmpty;

                          return GlassCard(
                            borderRadius: 18,
                            padding: const EdgeInsets.all(12),
                            borderColor: sent
                                ? const Color(0xFF34D399).withOpacity(0.5)
                                : Colors.white12,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.santri.namaLengkap,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B)
                                                  .withOpacity(0.18),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              item.badgeText,
                                              style: const TextStyle(
                                                color: Color(0xFFFDE68A),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.santri.kamar} • ${item.priorityDetail}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        sent
                                            ? '✓ Sudah Dikirim Hari Ini'
                                            : (hasPhone
                                                ? 'WA: ${item.santri.noWaWali}'
                                                : '⚠️ No. WA wali kosong'),
                                        style: TextStyle(
                                          color: sent
                                              ? const Color(0xFF34D399)
                                              : (hasPhone
                                                  ? const Color(0xFF67E8F9)
                                                  : const Color(0xFFFDA4AF)),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  children: [
                                    IconButton(
                                      tooltip: 'Kirim WA',
                                      onPressed: () => _sendItem(provider, item),
                                      icon: Icon(
                                        sent
                                            ? Icons.check_circle_rounded
                                            : Icons.chat_rounded,
                                        color: sent
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFF22C55E),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Salin Pesan',
                                      onPressed: () async {
                                        final msg =
                                            SmartWaReminderService.composePoliteMessage(
                                          item: item,
                                          namaPondok:
                                              provider.pengaturan.namaPondok,
                                        );
                                        await Clipboard.setData(
                                            ClipboardData(text: msg));
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Teks pengingat disalin ke clipboard.'),
                                              backgroundColor:
                                                  Color(0xFF10B981),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                        color: Colors.white60,
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
      ),
    );
  }

  Widget _catBtn(ReminderCategory cat, String label, Color accent) {
    final active = _selectedCategory == cat;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() => _selectedCategory = cat);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: active ? accent.withOpacity(0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: active ? Border.all(color: accent.withOpacity(0.6)) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? accent : Colors.white60,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
