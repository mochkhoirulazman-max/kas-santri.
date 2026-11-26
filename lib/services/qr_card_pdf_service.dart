import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pengaturan.dart';
import '../models/santri.dart';

/// Generator PDF A4 Cetak Massal Kartu Santri QR Siap Laminating (8 Kartu / Halaman).
class QrCardPdfService {
  static final QrCardPdfService instance = QrCardPdfService._init();
  QrCardPdfService._init();

  Future<Uint8List?> _loadLogoBytes(PengaturanAplikasi pengaturan) async {
    try {
      final path = pengaturan.logoPath;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) return await file.readAsBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _loadFotoBytes(String? fotoPath) async {
    if (fotoPath == null || fotoPath.trim().isEmpty) return null;
    try {
      final f = File(fotoPath);
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {}
    return null;
  }

  String _initials(String nama) {
    final parts = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'KS';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  /// Menghasilkan PDF A4 dengan 8 kartu ukuran standar ID Card per halaman (2 kolom x 4 baris).
  Future<Uint8List> buildBulkQrCardsPdfBytes({
    required PengaturanAplikasi pengaturan,
    required List<Santri> santriList,
  }) async {
    final doc = pw.Document();
    final logoBytes = await _loadLogoBytes(pengaturan);
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final fotoCache = <String, pw.MemoryImage>{};
    for (final s in santriList) {
      final b = await _loadFotoBytes(s.fotoPath);
      if (b != null) {
        fotoCache[s.id] = pw.MemoryImage(b);
      }
    }

    const cardsPerPage = 8;
    final totalPages =
        santriList.isEmpty ? 1 : (santriList.length / cardsPerPage).ceil();

    for (var pIdx = 0; pIdx < totalPages; pIdx++) {
      final start = pIdx * cardsPerPage;
      final end = (start + cardsPerPage) > santriList.length
          ? santriList.length
          : (start + cardsPerPage);
      final chunk = santriList.sublist(start, end);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'KARTU SANTRI QR — ${pengaturan.namaPondok.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal900,
                      ),
                    ),
                    pw.Text(
                      'Gunting mengikuti garis kotak kartu • Hal ${pIdx + 1}/$totalPages',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.58, // Rasio standar ID Card ~85.6 x 54 mm
                    children: chunk.map((s) {
                      return _buildSingleCard(
                        pengaturan: pengaturan,
                        santri: s,
                        logoImage: logoImage,
                        fotoImage: fotoCache[s.id],
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildSingleCard({
    required PengaturanAplikasi pengaturan,
    required Santri santri,
    pw.MemoryImage? logoImage,
    pw.MemoryImage? fotoImage,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey500, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header Pondok
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF064E3B),
              borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(7)),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 18,
                  height: 18,
                  decoration: pw.BoxDecoration(
                    color: logoImage != null
                        ? PdfColors.white
                        : const PdfColor.fromInt(0xFF0F766E),
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(
                      color: const PdfColor.fromInt(0xFFFBBF24),
                      width: 0.6,
                    ),
                  ),
                  padding: const pw.EdgeInsets.all(1.5),
                  alignment: pw.Alignment.center,
                  child: logoImage != null
                      ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                      : pw.Text(
                          'KS',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 6.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        pengaturan.namaPondok.toUpperCase(),
                        maxLines: 1,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'KARTU UANG SAKU SANTRI (${pengaturan.tahunAjaran})',
                        maxLines: 1,
                        style: const pw.TextStyle(
                          color: PdfColor.fromInt(0xFFA7F3D0),
                          fontSize: 5.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Kartu: Foto/Inisial + Identitas + QR Code
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Foto / Monogram
                  pw.Container(
                    width: 42,
                    height: 52,
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFECFDF5),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFF6EE7B7),
                        width: 0.8,
                      ),
                    ),
                    alignment: pw.Alignment.center,
                    child: fotoImage != null
                        ? pw.ClipRRect(
                            horizontalRadius: 5,
                            verticalRadius: 5,
                            child: pw.Image(fotoImage, fit: pw.BoxFit.cover),
                          )
                        : pw.Text(
                            _initials(santri.namaLengkap),
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF065F46),
                            ),
                          ),
                  ),
                  pw.SizedBox(width: 8),

                  // Identitas Santri
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          santri.namaLengkap,
                          maxLines: 2,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Kamar / Kelas: ${santri.kamar}',
                          maxLines: 1,
                          style: const pw.TextStyle(
                            fontSize: 7.5,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFFEF3C7),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            santri.kategoriLabel.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF92400E),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          santri.qrCode,
                          style: const pw.TextStyle(
                            fontSize: 6,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 6),

                  // QR Code Terbaca Scanner 1 Detik
                  pw.Container(
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(5),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                    ),
                    child: pw.SizedBox(
                      width: 56,
                      height: 56,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: santri.qrCode,
                        color: PdfColors.black,
                        backgroundColor: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer Strip
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF1F5F9),
              borderRadius:
                  pw.BorderRadius.vertical(bottom: pw.Radius.circular(7)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Scan saat antrean pengambilan kas harian',
                  style: const pw.TextStyle(
                    fontSize: 5.5,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Kas-Santri QR',
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
