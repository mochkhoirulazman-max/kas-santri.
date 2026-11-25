// CLI Tool Sekali Jalan: Generator Pasangan Kunci Ed25519 & Penandatangan Lisensi Kas-Santri v3.3
//
// Jalankan dari root proyek (JANGAN simpan Private Seed di dalam folder lib/ atau assets/):
//   1. Buat keypair baru:
//      dart run tool/generate_keypair.dart --generate-keys
//   2. Tanda tangani kode lisensi offline (simpan private seed hanya di PC admin):
//      dart run tool/generate_keypair.dart --sign --seed "<PRIVATE_SEED_BASE64>" --device "KS-ABCD1234" --tier YEARLY
//      dart run tool/generate_keypair.dart --sign --seed "<PRIVATE_SEED_BASE64>" --device "KS-ABCD1234" --tier LIFETIME
//
// Format kode keluaran: KSPRO-<PAYLOAD_B32>-<SIGNATURE_B32>
// Payload mentah (UTF-8): <DEVICE_ID>|<TIER>|<EXPIRY_EPOCH_SEC>

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const String _b32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

String encodeBase32(List<int> bytes) {
  if (bytes.isEmpty) return '';
  final out = StringBuffer();
  var buffer = 0;
  var bitsLeft = 0;
  for (final byte in bytes) {
    buffer = (buffer << 8) | (byte & 0xff);
    bitsLeft += 8;
    while (bitsLeft >= 5) {
      final index = (buffer >> (bitsLeft - 5)) & 0x1f;
      bitsLeft -= 5;
      out.write(_b32Alphabet[index]);
    }
  }
  if (bitsLeft > 0) {
    final index = (buffer << (5 - bitsLeft)) & 0x1f;
    out.write(_b32Alphabet[index]);
  }
  return out.toString();
}

Uint8List decodeBase32(String input) {
  final clean = input.trim().toUpperCase().replaceAll('=', '');
  final bytes = <int>[];
  var buffer = 0;
  var bitsLeft = 0;
  for (var i = 0; i < clean.length; i++) {
    final idx = _b32Alphabet.indexOf(clean[i]);
    if (idx < 0) {
      throw FormatException('Karakter Base32 tidak valid: ${clean[i]}');
    }
    buffer = (buffer << 5) | idx;
    bitsLeft += 5;
    if (bitsLeft >= 8) {
      bytes.add((buffer >> (bitsLeft - 8)) & 0xff);
      bitsLeft -= 8;
    }
  }
  return Uint8List.fromList(bytes);
}

String? _readFlag(List<String> args, String name) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == name && i + 1 < args.length) {
      return args[i + 1];
    }
    if (args[i].startsWith('$name=')) {
      return args[i].substring(name.length + 1);
    }
  }
  return null;
}

Future<void> _generateKeys() async {
  final algo = Ed25519();
  final keyPair = await algo.newKeyPair();
  final seedBytes = await keyPair.extractPrivateKeyBytes();
  final publicKey = await keyPair.extractPublicKey();

  final seedB64 = base64Encode(seedBytes);
  final pubB64 = base64Encode(publicKey.bytes);

  stdout.writeln('=== PASANGAN KUNCI ED25519 KAS-SANTRI v3.3 ===');
  stdout.writeln('');
  stdout.writeln('1. PRIVATE SEED (RAHASIA - SIMPAN HANYA DI ADMIN, JANGAN MASUKKAN KE lib/ ATAU git):');
  stdout.writeln('   $seedB64');
  stdout.writeln('');
  stdout.writeln('2. PUBLIC KEY (TEMPEL KE LicenseService.defaultPublicKeyBase64 di lib/services/license_service.dart):');
  stdout.writeln('   $pubB64');
  stdout.writeln('');
  stdout.writeln('Contoh perintah tanda tangan:');
  stdout.writeln('   dart run tool/generate_keypair.dart --sign --seed "$seedB64" --device "KS-A1B2C3D4" --tier YEARLY');
}

Future<void> _signLicense(List<String> args) async {
  final seedB64 = _readFlag(args, '--seed');
  final deviceRaw = _readFlag(args, '--device');
  final tierRaw = (_readFlag(args, '--tier') ?? 'YEARLY').trim().toUpperCase();
  final daysStr = _readFlag(args, '--days');
  final expiryStr = _readFlag(args, '--expiry');

  if (seedB64 == null || seedB64.isEmpty || deviceRaw == null || deviceRaw.isEmpty) {
    stderr.writeln('Error: --seed dan --device wajib diisi saat menggunakan --sign.');
    exitCode = 2;
    return;
  }

  if (tierRaw != 'MONTHLY' && tierRaw != 'YEARLY' && tierRaw != 'LIFETIME') {
    stderr.writeln('Error: --tier harus MONTHLY, YEARLY, atau LIFETIME.');
    exitCode = 2;
    return;
  }

  final int expiryEpochSec;
  if (expiryStr != null && expiryStr.isNotEmpty) {
    expiryEpochSec = int.parse(expiryStr);
  } else if (tierRaw == 'LIFETIME') {
    expiryEpochSec = 0; // 0 = seumur hidup tanpa kedaluwarsa
  } else {
    final defaultDays = tierRaw == 'MONTHLY' ? 31 : 366;
    final days = daysStr != null ? int.parse(daysStr) : defaultDays;
    expiryEpochSec =
        DateTime.now().toUtc().add(Duration(days: days)).millisecondsSinceEpoch ~/ 1000;
  }

  final deviceId = deviceRaw.trim().toUpperCase().replaceAll('|', '');
  final payloadString = '$deviceId|$tierRaw|$expiryEpochSec';
  final payloadBytes = utf8.encode(payloadString);

  final seedBytes = base64Decode(seedB64.trim());
  final algo = Ed25519();
  final keyPair = await algo.newKeyPairFromSeed(seedBytes);
  final publicKey = await keyPair.extractPublicKey();
  final signature = await algo.sign(payloadBytes, keyPair: keyPair);

  final verified = await algo.verify(payloadBytes, signature: signature);
  if (!verified) {
    stderr.writeln('Error internal: verifikasi tanda tangan gagal.');
    exitCode = 1;
    return;
  }

  final payloadB32 = encodeBase32(payloadBytes);
  final sigB32 = encodeBase32(signature.bytes);
  final code = 'KSPRO-$payloadB32-$sigB32';

  stdout.writeln('=== KODE LISENSI ED25519 KAS-SANTRI PRO ===');
  stdout.writeln('Device ID   : $deviceId');
  stdout.writeln('Tier        : $tierRaw');
  stdout.writeln('ExpiryEpoch : $expiryEpochSec (${expiryEpochSec == 0 ? "LIFETIME" : DateTime.fromMillisecondsSinceEpoch(expiryEpochSec * 1000, isUtc: true).toIso8601String()})');
  stdout.writeln('Public Key  : ${base64Encode(publicKey.bytes)}');
  stdout.writeln('');
  stdout.writeln('KODE AKTIVASI:');
  stdout.writeln(code);
}

Future<void> main(List<String> args) async {
  if (args.contains('--sign')) {
    await _signLicense(args);
    return;
  }
  await _generateKeys();
}
