import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/santri.dart';
import '../providers/theme_wallpaper_provider.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';

/// Field kaca modern pengganti DropdownButton untuk memilih santri secara instan & akurat
class SearchableSantriField extends StatelessWidget {
  final Santri? selectedSantri;
  final bool isAllSelected;
  final String allLabel;
  final String placeholder;
  final VoidCallback onTap;
  final bool compact;

  const SearchableSantriField({
    Key? key,
    this.selectedSantri,
    this.isAllSelected = false,
    this.allLabel = 'Semua Santri',
    this.placeholder = 'Cari & pilih santri...',
    required this.onTap,
    this.compact = false,
  }) : super(key: key);

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'KS';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final s = selectedSantri;
    final hasFoto =
        !isAllSelected && s != null && s.fotoPath != null && s.fotoPath!.isNotEmpty && File(s.fotoPath!).existsSync();

    return InkWell(
      onTap: () {
        AppFeedback.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF060B14).withOpacity((0.85 * cardOpacity).clamp(0.45, 0.9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (s != null || isAllSelected)
                ? const Color(0xFF38BDF8).withOpacity(0.42)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 30 : 38,
              height: compact ? 30 : 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAllSelected
                      ? const [Color(0xFF38BDF8), Color(0xFF818CF8)]
                      : const [Color(0xFF10B981), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(compact ? 10 : 12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 10 : 12),
                child: isAllSelected
                    ? Center(
                        child: Text(
                          '👥',
                          style: TextStyle(fontSize: compact ? 14 : 17),
                        ),
                      )
                    : (hasFoto
                        ? Image.file(File(s.fotoPath!), fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              s != null ? _initials(s.namaLengkap) : '?',
                              style: TextStyle(
                                color: const Color(0xFF040914),
                                fontSize: compact ? 10 : 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )),
              ),
            ),
            SizedBox(width: compact ? 8 : 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAllSelected
                        ? allLabel
                        : (s != null ? s.namaLengkap : placeholder),
                    style: TextStyle(
                      color: (s != null || isAllSelected) ? Colors.white : Colors.white54,
                      fontSize: compact ? 11.5 : 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isAllSelected && s != null) ...[
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${s.kategoriLabel}${s.kamar.trim().isNotEmpty ? ' • ${s.kamar}' : ''}',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                        Text(
                          'Saldo ${CurrencyFormatter.format(s.saldoTotal)}',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (s.tunggakan > 0)
                          Text(
                            '• Tunggakan ${CurrencyFormatter.format(s.tunggakan)}',
                            style: const TextStyle(
                              color: Color(0xFFFDA4AF),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: EdgeInsets.all(compact ? 4 : 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.search_rounded,
                color: const Color(0xFF67E8F9),
                size: compact ? 15 : 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet Glassmorphism dengan pencarian real-time Nama Lengkap, Panggilan & Kamar
class SearchableSantriPicker extends StatefulWidget {
  final List<Santri> santriList;
  final String? selectedSantriId;
  final bool allowAllOption;
  final String allOptionLabel;
  final String title;

  const SearchableSantriPicker({
    Key? key,
    required this.santriList,
    this.selectedSantriId,
    this.allowAllOption = false,
    this.allOptionLabel = 'Semua Santri',
    this.title = 'Pilih Santri',
  }) : super(key: key);

  static Future<String?> show(
    BuildContext context, {
    required List<Santri> santriList,
    String? selectedSantriId,
    bool allowAllOption = false,
    String allOptionLabel = 'Semua Santri',
    String title = 'Pilih Santri',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchableSantriPicker(
        santriList: santriList,
        selectedSantriId: selectedSantriId,
        allowAllOption: allowAllOption,
        allOptionLabel: allOptionLabel,
        title: title,
      ),
    );
  }

  @override
  State<SearchableSantriPicker> createState() => _SearchableSantriPickerState();
}

class _SearchableSantriPickerState extends State<SearchableSantriPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _kategoriFilter = 'ALL'; // ALL, SANTRIYIN, SANTRIYAT, SANTRI_BARU
  String? _kamarFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'KS';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    final kamarSet = widget.santriList
        .map((s) => s.kamar.trim())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final q = _query.trim().toLowerCase();
    final filtered = widget.santriList.where((s) {
      if (_kategoriFilter != 'ALL' && s.kategoriSantri != _kategoriFilter) {
        return false;
      }
      if (_kamarFilter != null && s.kamar.trim() != _kamarFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.namaLengkap.toLowerCase().contains(q) ||
          s.namaPanggilan.toLowerCase().contains(q) ||
          s.kamar.toLowerCase().contains(q);
    }).toList();

    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A1120).withOpacity((cardOpacity + 0.16).clamp(0.76, 0.96)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.45), width: 1.4),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${filtered.length} santri',
                            style: const TextStyle(
                              color: Color(0xFF67E8F9),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Kolom Pencarian Real-Time
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ketik nama lengkap, panggilan, atau kamar...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF67E8F9)),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Cepat Kategori + Kamar
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      children: [
                        _chip('Semua', _kategoriFilter == 'ALL' && _kamarFilter == null, () {
                          setState(() {
                            _kategoriFilter = 'ALL';
                            _kamarFilter = null;
                          });
                        }),
                        _chip('Santriyin', _kategoriFilter == Santri.kategoriSantriyin, () {
                          setState(() {
                            _kategoriFilter = _kategoriFilter == Santri.kategoriSantriyin
                                ? 'ALL'
                                : Santri.kategoriSantriyin;
                          });
                        }),
                        _chip('Santriyat', _kategoriFilter == Santri.kategoriSantriyat, () {
                          setState(() {
                            _kategoriFilter = _kategoriFilter == Santri.kategoriSantriyat
                                ? 'ALL'
                                : Santri.kategoriSantriyat;
                          });
                        }),
                        _chip('Santri Baru', _kategoriFilter == Santri.kategoriSantriBaru, () {
                          setState(() {
                            _kategoriFilter = _kategoriFilter == Santri.kategoriSantriBaru
                                ? 'ALL'
                                : Santri.kategoriSantriBaru;
                          });
                        }),
                        ...kamarSet.take(8).map((k) {
                          return _chip(k, _kamarFilter == k, () {
                            setState(() {
                              _kamarFilter = _kamarFilter == k ? null : k;
                            });
                          }, accent: const Color(0xFF38BDF8));
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),

                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 18 + bottomSafe),
                      children: [
                        if (widget.allowAllOption)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: widget.selectedSantriId == 'ALL'
                                  ? const Color(0xFF10B981).withOpacity(0.18)
                                  : Colors.black.withOpacity(0.28),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: widget.selectedSantriId == 'ALL'
                                    ? const Color(0xFF34D399)
                                    : Colors.white12,
                              ),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF0A203A),
                                child: Text('👥', style: TextStyle(fontSize: 16)),
                              ),
                              title: Text(
                                widget.allOptionLabel,
                                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                              ),
                              subtitle: const Text(
                                'Tampilkan mutasi seluruh santri',
                                style: TextStyle(color: Colors.white54, fontSize: 10.5),
                              ),
                              trailing: widget.selectedSantriId == 'ALL'
                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399))
                                  : null,
                              onTap: () {
                                AppFeedback.tap();
                                Navigator.pop(context, 'ALL');
                              },
                            ),
                          ),

                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: Center(
                              child: Text(
                                'Santri tidak ditemukan pada pencarian ini.',
                                style: TextStyle(color: Colors.white54, fontSize: 12.5),
                              ),
                            ),
                          )
                        else
                          ...filtered.map((s) {
                            final isSelected = widget.selectedSantriId == s.id;
                            final hasFoto = s.fotoPath != null &&
                                s.fotoPath!.isNotEmpty &&
                                File(s.fotoPath!).existsSync();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withOpacity(0.18)
                                    : Colors.black.withOpacity(0.28),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF34D399) : Colors.white12,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF0F272E),
                                  backgroundImage: hasFoto ? FileImage(File(s.fotoPath!)) : null,
                                  child: hasFoto
                                      ? null
                                      : Text(
                                          _initials(s.namaLengkap),
                                          style: const TextStyle(
                                            color: Color(0xFF34D399),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.namaLengkap,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (s.isPulang || s.isPindah)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: s.isPulang
                                              ? const Color(0xFF34D399).withOpacity(0.2)
                                              : const Color(0xFF94A3B8).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          s.isPulang ? 'PULANG' : 'PINDAH',
                                          style: TextStyle(
                                            color: s.isPulang
                                                ? const Color(0xFF6EE7B7)
                                                : const Color(0xFFE2E8F0),
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        '${s.kategoriLabel}${s.kamar.trim().isNotEmpty ? ' • ${s.kamar}' : ''}',
                                        style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                                      ),
                                      Text(
                                        'Saldo: ${CurrencyFormatter.format(s.saldoTotal)}',
                                        style: const TextStyle(
                                          color: Color(0xFF34D399),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      if (s.tunggakan > 0)
                                        Text(
                                          'Tunggakan: ${CurrencyFormatter.format(s.tunggakan)}',
                                          style: const TextStyle(
                                            color: Color(0xFFFDA4AF),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20)
                                    : const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                                onTap: () {
                                  AppFeedback.tap();
                                  Navigator.pop(context, s.id);
                                },
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color accent = const Color(0xFF34D399),
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.22) : Colors.black.withOpacity(0.32),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? accent : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accent : Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
