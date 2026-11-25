import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuditLogVerificationResult {
  final bool isValid;
  final int totalEntries;
  final int? brokenIndex;
  final String? brokenId;
  final String message;

  const AuditLogVerificationResult({
    required this.isValid,
    required this.totalEntries,
    this.brokenIndex,
    this.brokenId,
    required this.message,
  });
}

/// Entri Jejak Audit Keamanan (Immutable & Hash-Chained) Kas-Santri v3.3.
/// Setiap baris mengikat hash SHA-256 dari baris sebelumnya (`prevHash -> entryHash`).
class AuditLogEntry {
  static const String genesisHash = 'GENESIS';

  final String id;
  final String createdAt;
  final String actor;
  final String action;
  final String? targetId;
  final String summary;
  final String prevHash;
  final String entryHash;

  const AuditLogEntry({
    required this.id,
    required this.createdAt,
    required this.actor,
    required this.action,
    this.targetId,
    required this.summary,
    required this.prevHash,
    required this.entryHash,
  });

  static String computeChainHash({
    required String id,
    required String createdAt,
    required String actor,
    required String action,
    String? targetId,
    required String summary,
    required String prevHash,
  }) {
    final payload =
        '$id|$createdAt|${actor.trim()}|${action.trim()}|${(targetId ?? '').trim()}|${summary.trim()}|${prevHash.trim()}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'created_at': createdAt,
        'actor': actor,
        'action': action,
        'target_id': targetId,
        'summary': summary,
        'prev_hash': prevHash,
        'entry_hash': entryHash,
      };

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) => AuditLogEntry(
        id: map['id']?.toString() ?? '',
        createdAt: map['created_at']?.toString() ?? '',
        actor: map['actor']?.toString() ?? 'Bendahara',
        action: map['action']?.toString() ?? '',
        targetId: map['target_id']?.toString(),
        summary: map['summary']?.toString() ?? '',
        prevHash: map['prev_hash']?.toString() ?? genesisHash,
        entryHash: map['entry_hash']?.toString() ?? '',
      );

  /// Memverifikasi integritas rantai SHA-256 dari urutan tertua -> terbaru.
  static AuditLogVerificationResult verifyChain(
    List<AuditLogEntry> orderedOldestFirst,
  ) {
    if (orderedOldestFirst.isEmpty) {
      return const AuditLogVerificationResult(
        isValid: true,
        totalEntries: 0,
        message: 'Belum ada entri audit tercatat. Rantai bersih.',
      );
    }

    var expectedPrev = genesisHash;
    for (var i = 0; i < orderedOldestFirst.length; i++) {
      final entry = orderedOldestFirst[i];
      if (entry.prevHash != expectedPrev) {
        return AuditLogVerificationResult(
          isValid: false,
          totalEntries: orderedOldestFirst.length,
          brokenIndex: i,
          brokenId: entry.id,
          message:
              'Terdeteksi rantai audit terputus di entri #${i + 1} (${entry.action}).',
        );
      }

      final expectedHash = computeChainHash(
        id: entry.id,
        createdAt: entry.createdAt,
        actor: entry.actor,
        action: entry.action,
        targetId: entry.targetId,
        summary: entry.summary,
        prevHash: entry.prevHash,
      );
      if (entry.entryHash != expectedHash) {
        return AuditLogVerificationResult(
          isValid: false,
          totalEntries: orderedOldestFirst.length,
          brokenIndex: i,
          brokenId: entry.id,
          message:
              'Terdeteksi modifikasi tidak sah pada entri #${i + 1} (${entry.action}).',
        );
      }
      expectedPrev = entry.entryHash;
    }

    return AuditLogVerificationResult(
      isValid: true,
      totalEntries: orderedOldestFirst.length,
      message:
          'Integritas Terverifikasi: ${orderedOldestFirst.length} catatan audit utuh tanpa modifikasi.',
    );
  }
}
