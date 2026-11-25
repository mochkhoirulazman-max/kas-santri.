import 'package:shared_preferences/shared_preferences.dart';
import '../models/infak_santri.dart';
import '../models/santri.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

enum ReminderCategory { saldoKritis, infakJatuhTempo, tunggakan }

class ReminderQueueItem {
  final ReminderCategory category;
  final Santri santri;
  final InfakSantriModel? infak;
  final String badgeText;
  final String priorityDetail;

  const ReminderQueueItem({
    required this.category,
    required this.santri,
    this.infak,
    required this.badgeText,
    required this.priorityDetail,
  });

  String get uniqueKey => '${category.name}:${santri.id}';
}

/// Mesin Antrean Pengingat WA Cerdas (Smart WA Reminder Queue) v4.0.
/// Mengelompokkan prioritas tanpa spam & menyimpan tanda kirim harian di lokal.
class SmartWaReminderService {
  static final SmartWaReminderService instance =
      SmartWaReminderService._init();
  SmartWaReminderService._init();

  static String _prefsKeyForDate(DateTime date) =>
      'ks_v40_wa_sent_${DateFormatter.toLocalDateString(date)}';

  static Map<ReminderCategory, List<ReminderQueueItem>> buildPriorityQueues({
    required List<Santri> activeSantri,
    required List<InfakSantriModel> infakPeriodeList,
    DateTime? now,
  }) {
    final refNow = (now ?? DateTime.now()).toLocal();
    final today = DateTime(refNow.year, refNow.month, refNow.day);

    final infakMap = <String, InfakSantriModel>{
      for (final i in infakPeriodeList) i.santriId: i,
    };

    final kritis = <ReminderQueueItem>[];
    final infakTempo = <ReminderQueueItem>[];
    final tunggakanList = <ReminderQueueItem>[];

    for (final s in activeSantri) {
      if (!s.isAktifDiPondok) continue;

      // 1. Saldo Kritis (< 3 hari)
      if (s.estimasiHari < 3) {
        kritis.add(
          ReminderQueueItem(
            category: ReminderCategory.saldoKritis,
            santri: s,
            badgeText: 'Sisa ${s.estimasiHari} Hari',
            priorityDetail:
                'Saldo tersisa ${CurrencyFormatter.format(s.saldoTotal)} (Jatah ${CurrencyFormatter.format(s.jatahHarian)}/hari)',
          ),
        );
      }

      // 2. Infak Jatuh Tempo (H-3 s.d. lewat tgl habis, atau belum lunas)
      final inf = infakMap[s.id];
      if (inf == null || inf.statusLunas != InfakSantriModel.statusLunasVal) {
        final badge = inf == null
            ? 'Belum Bayar'
            : (inf.statusLunas == InfakSantriModel.statusCicilVal
                ? 'Masih Cicil'
                : 'Belum Lunas');
        infakTempo.add(
          ReminderQueueItem(
            category: ReminderCategory.infakJatuhTempo,
            santri: s,
            infak: inf,
            badgeText: badge,
            priorityDetail: inf == null
                ? 'Infak bulan ini belum tercatat lunas'
                : 'Infak periode ${inf.periodeBulan} berstatus $badge',
          ),
        );
      } else {
        final habis = DateTime.tryParse(inf.tglHabis);
        if (habis != null) {
          final habisDate = DateTime(habis.year, habis.month, habis.day);
          final diffDays = habisDate.difference(today).inDays;
          if (diffDays <= 3) {
            infakTempo.add(
              ReminderQueueItem(
                category: ReminderCategory.infakJatuhTempo,
                santri: s,
                infak: inf,
                badgeText: diffDays < 0
                    ? 'Lewat ${diffDays.abs()}h'
                    : (diffDays == 0 ? 'Jatuh Tempo' : 'H-$diffDays'),
                priorityDetail: 'Tgl habis infak: ${inf.tglHabis}',
              ),
            );
          }
        }
      }

      // 3. Tunggakan Aktif
      if (s.tunggakan > 0) {
        tunggakanList.add(
          ReminderQueueItem(
            category: ReminderCategory.tunggakan,
            santri: s,
            badgeText: CurrencyFormatter.format(s.tunggakan),
            priorityDetail: s.catatanTunggakan.isNotEmpty
                ? s.catatanTunggakan
                : 'Talangan kas pondok belum dilunasi',
          ),
        );
      }
    }

    return {
      ReminderCategory.saldoKritis: kritis,
      ReminderCategory.infakJatuhTempo: infakTempo,
      ReminderCategory.tunggakan: tunggakanList,
    };
  }

  /// Menyusun pesan pengingat santun berbahasa pesantren dengan nominal akurat.
  static String composePoliteMessage({
    required ReminderQueueItem item,
    required String namaPondok,
  }) {
    final s = item.santri;
    final header = '*Assalamu’alaikum Warahmatullahi Wabarakatuh* 🌸\n\n'
        'Yth. *Bapak/Ibu Wali Santri* dari ananda *${s.namaLengkap}* (${s.kamar}),\n'
        'Semoga Bapak/Ibu sekeluarga selalu diberi kesehatan dan keberkahan.\n\n';
    final footer =
        '\n\nApabila hendak mengirimkan titipan atau konfirmasi, silakan membalas pesan ini. '
        'Jazakumullah khairan katsiran.\n'
        '*Wassalamu’alaikum Warahmatullahi Wabarakatuh* 🙏\n'
        '_Pengurus Kas & Keuangan ${namaPondok}_';

    switch (item.category) {
      case ReminderCategory.saldoKritis:
        return '${header}Dengan hormat kami menginformasikan bahwa saldo titipan uang saku ananda saat ini tersisa '
            '*${CurrencyFormatter.format(s.saldoTotal)}* (estimasi cukup sekitar *${s.estimasiHari} hari* dengan jatah ${CurrencyFormatter.format(s.jatahHarian)}/hari).\n'
            'Mohon berkenan menyiapkan kiriman setoran berikutnya agar kebutuhan harian ananda tetap lancar.$footer';
      case ReminderCategory.infakJatuhTempo:
        final tglInfo = item.infak != null
            ? ' (jatuh tempo: *${item.infak!.tglHabis}*)'
            : '';
        return '${header}Dengan hormat kami mengingatkan kewajiban *Infak Bulanan Pondok* (Masak, Listrik & Beras) '
            'ananda saat ini berstatus *${item.badgeText}*$tglInfo.\n'
            'Kami ucapkan terima kasih atas perhatian dan kerja sama Bapak/Ibu.$footer';
      case ReminderCategory.tunggakan:
        final ket = s.catatanTunggakan.isNotEmpty ? ' (${s.catatanTunggakan})' : '';
        return '${header}Dengan hormat kami menyampaikan informasi bahwa ananda masih memiliki catatan administrasi/tunggakan '
            'sebesar *${CurrencyFormatter.format(s.tunggakan)}*$ket.\n'
            'Pelunasan dapat dititipkan saat sambangan atau digabungkan dengan setoran berikutnya.$footer';
    }
  }

  Future<Set<String>> getSentKeysToday({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKeyForDate(now ?? DateTime.now());
    return (prefs.getStringList(key) ?? const []).toSet();
  }

  Future<Set<String>> markSentToday(String uniqueKey, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKeyForDate(now ?? DateTime.now());
    final set = (prefs.getStringList(key) ?? const []).toSet();
    set.add(uniqueKey);
    await prefs.setStringList(key, set.toList());
    return set;
  }
}
