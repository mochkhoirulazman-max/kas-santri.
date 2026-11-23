import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/santri_card.dart';
import '../widgets/fast_withdrawal_bottom_sheet.dart';
import 'santri/santri_detail_screen.dart';

class HomeFastWithdrawalScreen extends StatefulWidget {
  const HomeFastWithdrawalScreen({Key? key}) : super(key: key);

  @override
  State<HomeFastWithdrawalScreen> createState() =>
      _HomeFastWithdrawalScreenState();
}

class _HomeFastWithdrawalScreenState extends State<HomeFastWithdrawalScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredList = provider.filteredSantriStatusList;

    return RefreshIndicator(
      onRefresh: () => provider.loadAllData(),
      child: CustomScrollView(
        slivers: [
          // 1. Hero Card: Total Uang Titipan (Brankas Fisik)
          SliverToBoxAdapter(
            child: SafeVaultCard(
              totalBrankas: provider.totalBrankasFisik,
              totalKeluarHariIni: provider.totalPengeluaranHariIni,
              jumlahTransaksi: provider.jumlahTransaksiHariIni,
            ),
          ),

          // 2. Baris Pencarian Instan (Pilih Santri Cepat)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama, panggilan, atau kamar...',
                  prefixIcon: const Icon(Icons.search, color: Colors.teal),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
                onChanged: (val) {
                  provider.setSearchQuery(val);
                },
              ),
            ),
          ),

          // 3. Filter Kamar Horizontal Chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Semua Kamar'),
                      selected: provider.selectedKamar == null || provider.selectedKamar!.isEmpty,
                      onSelected: (selected) {
                        provider.setSelectedKamar(null);
                      },
                      selectedColor: const Color(0xFF00796B),
                      labelStyle: TextStyle(
                        color: (provider.selectedKamar == null || provider.selectedKamar!.isEmpty)
                            ? Colors.white
                            : Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...provider.kamars.map((kamar) {
                    final isSelected = provider.selectedKamar == kamar;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(kamar),
                        selected: isSelected,
                        onSelected: (selected) {
                          provider.setSelectedKamar(selected ? kamar : null);
                        },
                        selectedColor: const Color(0xFF00796B),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          // 4. Santri Sering / Baru Saja Bertransaksi (Pilihan Cepat)
          if (provider.recentSantri.isNotEmpty && _searchController.text.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.history, size: 14, color: Colors.teal),
                        SizedBox(width: 4),
                        Text(
                          'Santri Terakhir / Sering Ambil Uang',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.recentSantri.length,
                        itemBuilder: (ctx, idx) {
                          final santri = provider.recentSantri[idx];
                          final status = provider.santriStatusList
                              .firstWhere((s) => s.santri.id == santri.id);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: CircleAvatar(
                                backgroundColor: const Color(0xFF00796B),
                                child: Text(
                                  santri.namaPanggilan.isNotEmpty
                                      ? santri.namaPanggilan[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                              label: Text(
                                santri.namaPanggilan.isNotEmpty
                                    ? santri.namaPanggilan
                                    : santri.namaLengkap,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: Colors.teal.shade200),
                              onPressed: () {
                                FastWithdrawalBottomSheet.show(context, status);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Daftar Santri & Status Hari Ini
          if (filteredList.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Tidak ada santri yang cocok dengan pencarian.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final status = filteredList[index];
                  return SantriCard(
                    status: status,
                    onDetailTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SantriDetailScreen(santriId: status.santri.id),
                        ),
                      );
                    },
                  );
                },
                childCount: filteredList.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}
