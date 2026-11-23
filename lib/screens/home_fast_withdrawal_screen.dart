import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/santri_status.dart';
import '../providers/kas_santri_provider.dart';
import '../services/auth_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/santri_card.dart';
import '../widgets/fast_withdrawal_bottom_sheet.dart';
import '../widgets/tunggakan_bottom_sheet.dart';
import '../widgets/tambah_santri_bottom_sheet.dart';
import 'pin_lock_screen.dart';

class HomeFastWithdrawalScreen extends StatefulWidget {
  const HomeFastWithdrawalScreen({Key? key}) : super(key: key);

  @override
  State<HomeFastWithdrawalScreen> createState() => _HomeFastWithdrawalScreenState();
}

class _HomeFastWithdrawalScreenState extends State<HomeFastWithdrawalScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showBanner = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final provider = Provider.of<KasSantriProvider>(context, listen: false);
      await provider.updateLogoPath(result.files.single.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo pondok berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _lockAppNow() async {
    await AuthService.instance.lockSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PinLockScreen(isUnlockingSession: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final isTwoCol = provider.pengaturan.isTwoColGrid;
    final filteredList = provider.filteredSantriStatusList;

    return Stack(
      children: [
        // Ambient glow background
        Positioned(
          top: -60,
          left: -40,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.2),
            ),
          ),
        ),
        Positioned(
          top: 140,
          right: -50,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF06B6D4).withOpacity(0.18),
            ),
          ),
        ),

        CustomScrollView(
          slivers: [
            // Status bar info & Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 44, 16, 8),
                child: Column(
                  children: [
                    // Status bar mobile
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '23 Nov 2026 • 16:00',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.circle, size: 6, color: Color(0xFF34D399)),
                              SizedBox(width: 4),
                              Text(
                                'Sistem Aktif',
                                style: TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Header Utama: Logo, Judul & Tombol Aksi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Logo Tap-to-Change
                            InkWell(
                              onTap: _pickLogo,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 44,
                                height: 44,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF34D399), Color(0xFF38BDF8), Color(0xFFD946EF)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    color: const Color(0xFF030712),
                                    padding: const EdgeInsets.all(2),
                                    child: provider.pengaturan.logoPath != null &&
                                            File(provider.pengaturan.logoPath!).existsSync()
                                        ? Image.file(
                                            File(provider.pengaturan.logoPath!),
                                            fit: BoxFit.contain,
                                          )
                                        : Image.asset(
                                            'logo.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => const Center(
                                              child: Text('PPS', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11)),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'KAS & KEUANGAN SANTRI',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'PPS MIFTAHUSSUNAN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Tombol "+ Santri" & "🔒"
                        Row(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: const Color(0xFF04121A),
                              ),
                              onPressed: () => TambahSantriBottomSheet.show(context),
                              child: const Row(
                                children: [
                                  Icon(Icons.add, size: 14),
                                  SizedBox(width: 2),
                                  Text('+ Santri', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _lockAppNow,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                alignment: Alignment.center,
                                child: const Text('🔒', style: TextStyle(fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Hero Card: Total Uang Titipan (Brankas Fisik)
            SliverToBoxAdapter(
              child: SafeVaultCard(
                totalBrankas: provider.totalBrankasFisik,
                totalKeluarHariIni: provider.totalPengeluaranHariIni,
                totalKuotaHariIni: provider.totalKuotaHariIni,
                totalTunggakan: provider.totalTunggakanPondok,
                countTunggakan: provider.countSantriTunggakan,
                jumlahSantri: provider.allSantri.where((s) => s.statusAktif).length,
                isHidden: provider.pengaturan.hideBalance,
                onToggleHide: provider.toggleHideBalance,
                onTunggakanTap: () => provider.setFilter('TUNGGAKAN'),
              ),
            ),

            // Banner Panduan Tombol Kartu 2 Kotak & Tunggakan
            if (_showBanner)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xE6052E26), Color(0xE6081E2E), Color(0xE6260B24)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'TOMBOL KARTU 2 KOTAK & FITUR TUNGGAKAN',
                              style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Ketuk kartu santri untuk Ambil Uang Harian, atau ketuk tombol 🚨 Tunggakan untuk mencatat/melunasi tunggakan santri.',
                              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 10.5, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _showBanner = false),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 14, color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bar Pencarian & Switcher 2 Kotak vs 1 Baris
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Cari nama santri atau kamar...',
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF38BDF8)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                  onPressed: () {
                                    _searchController.clear();
                                    provider.setSearchQuery('');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        ),
                        onChanged: (val) => provider.setSearchQuery(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: provider.toggleGridLayout,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Text('⊞', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Text(
                              isTwoCol ? '2 Kotak' : '1 Baris',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter Pills Horizontal
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    _buildFilterPill('✨ Semua', 'ALL', provider),
                    _buildFilterPill('🚨 Ada Tunggakan', 'TUNGGAKAN', provider, isRed: true),
                    _buildFilterPill('🟢 Utuh', 'UTUH', provider),
                    _buildFilterPill('🔵 Sebagian', 'SEBAGIAN', provider),
                    _buildFilterPill('🟡 Limit Habis', 'HABIS', provider),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // Daftar Kartu Santri
            if (filteredList.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🔍', style: TextStyle(fontSize: 32)),
                        SizedBox(height: 8),
                        Text('Santri Tidak Ditemukan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Coba kata kunci pencarian atau filter lainnya.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              )
            else if (isTwoCol)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final status = filteredList[idx];
                      return SantriCard(
                        status: status,
                        isTwoCol: true,
                        onAmbilTap: () => FastWithdrawalBottomSheet.show(context, status),
                        onTunggakanTap: () => TunggakanBottomSheet.show(context, status.santri),
                      );
                    },
                    childCount: filteredList.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final status = filteredList[idx];
                      return SantriCard(
                        status: status,
                        isTwoCol: false,
                        onAmbilTap: () => FastWithdrawalBottomSheet.show(context, status),
                        onTunggakanTap: () => TunggakanBottomSheet.show(context, status.santri),
                      );
                    },
                    childCount: filteredList.length,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterPill(String label, String filterKey, KasSantriProvider provider, {bool isRed = false}) {
    final isSelected = provider.activeFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => provider.setFilter(filterKey),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? (isRed
                    ? const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFD946EF)])
                    : const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF38BDF8)]))
                : null,
            color: isSelected ? null : (isRed ? const Color(0xFF3F0A18).withOpacity(0.5) : const Color(0xFF0F172A)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isRed ? const Color(0xFFFB7185).withOpacity(0.4) : Colors.white12),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isRed ? const Color(0xFFF43F5E) : const Color(0xFF10B981)).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF030712) : (isRed ? const Color(0xFFFECDD3) : Colors.white70),
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
