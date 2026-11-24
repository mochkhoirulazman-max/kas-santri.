import 'dart:convert';

class CashOpnameLog {
  final String id;
  final String tanggalLokal;
  final int totalSistem;
  final int totalFisik;
  final int selisih;
  final Map<int, int> rincianPecahan;
  final String? catatan;
  final DateTime createdAt;

  CashOpnameLog({
    required this.id,
    required this.tanggalLokal,
    required this.totalSistem,
    required this.totalFisik,
    required this.selisih,
    required this.rincianPecahan,
    this.catatan,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCocok => selisih == 0;

  Map<String, dynamic> toMap() {
    final jsonMap = <String, int>{};
    for (final entry in rincianPecahan.entries) {
      jsonMap[entry.key.toString()] = entry.value;
    }
    return {
      'id': id,
      'tanggal_lokal': tanggalLokal,
      'total_sistem': totalSistem,
      'total_fisik': totalFisik,
      'selisih': selisih,
      'rincian_pecahan_json': jsonEncode(jsonMap),
      'catatan': catatan,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CashOpnameLog.fromMap(Map<String, dynamic> map) {
    final Map<int, int> parsedPecahan = {};
    final rawJson = map['rincian_pecahan_json'] as String?;
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final denom = int.tryParse(entry.key);
          final qty = (entry.value as num?)?.toInt();
          if (denom != null && qty != null) {
            parsedPecahan[denom] = qty;
          }
        }
      } catch (_) {}
    }

    return CashOpnameLog(
      id: map['id'] as String,
      tanggalLokal: map['tanggal_lokal'] as String? ?? '',
      totalSistem: (map['total_sistem'] as num?)?.toInt() ?? 0,
      totalFisik: (map['total_fisik'] as num?)?.toInt() ?? 0,
      selisih: (map['selisih'] as num?)?.toInt() ?? 0,
      rincianPecahan: parsedPecahan,
      catatan: map['catatan'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
