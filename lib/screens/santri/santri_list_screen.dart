import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/kas_santri_provider.dart';
import '../../widgets/santri_card.dart';
import '../../widgets/fast_withdrawal_bottom_sheet.dart';
import '../../widgets/tunggakan_bottom_sheet.dart';
import 'santri_form_screen.dart';
import 'santri_detail_screen.dart';

class SantriListScreen extends StatefulWidget {
  const SantriListScreen({Key? key}) : super(key: key);

  @override
  State<SantriListScreen> createState() => _SantriListScreenState();
}

class _SantriListScreenState extends State<SantriListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final filteredList = provider.filteredSantriStatusList;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Search & Filter Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama santri atau kamar...',
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
                onChanged: (val) => provider.setSearchQuery(val),
              ),
            ),
          ),

          // Horizontal Kamar Filter
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
                      label: Text('Semua (${provider.santriStatusList.length})'),
                      selected: provider.selectedKamar == null || provider.selectedKamar!.isEmpty,
                      onSelected: (selected) => provider.setSelectedKamar(null),
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
                    final count = provider.santriStatusList
                        .where((s) => s.santri.kamar == kamar)
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$kamar ($count)'),
                        selected: isSelected,
                        onSelected: (selected) =>
                            provider.setSelectedKamar(selected ? kamar : null),
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

          const SliverToBoxAdapter(child: SizedBox(height: 6)),

          if (filteredList.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('Data santri tidak ditemukan.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final status = filteredList[index];
                  return SantriCard(
                    status: status,
                    isTwoCol: false,
                    onAmbilTap: () => FastWithdrawalBottomSheet.show(context, status),
                    onTunggakanTap: () => TunggakanBottomSheet.show(context, status.santri),
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

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Santri'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SantriFormScreen()),
          );
        },
      ),
    );
  }
}
