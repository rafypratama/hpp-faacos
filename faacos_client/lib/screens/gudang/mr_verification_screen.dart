import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/formatter.dart';
import '../../providers/production_provider.dart';
import '../../models/material_request_model.dart';
import '../widgets/chemical_particle_background.dart';

class MrVerificationScreen extends StatefulWidget {
  const MrVerificationScreen({super.key});

  @override
  State<MrVerificationScreen> createState() => _MrVerificationScreenState();
}

class _MrVerificationScreenState extends State<MrVerificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductionProvider>(context, listen: false).fetchMaterialRequests();
    });
  }

  void _showVerificationDialog(BuildContext context, MaterialRequestModel mr) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mr.code,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
              ),
              const Text(
                'Verifikasi Material Request',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formula: ${mr.productionOrder?.formula?.name ?? "-"}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                  ),
                  Text(
                    'Target: ${mr.productionOrder?.targetQuantity ?? 0} kg (${mr.productionOrder?.batchCount ?? 0} batch)',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Daftar Pengeluaran Bahan Baku:',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mr.items.length,
                    itemBuilder: (context, index) {
                      final item = mr.items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.ingredient?.name ?? 'Bahan',
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Stok Gudang: ${item.ingredient?.currentStock ?? 0} ${item.ingredient?.unit ?? ""}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${item.quantityRequired} ${item.unit}',
                              style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Rejection Reason Input
                  TextFormField(
                    controller: reasonController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Catatan Penolakan (Wajib jika TOLAK)',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceElevated)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            // Reject Action
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sebutkan alasan penolakan permintaan.'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _handleVerify(context, mr.id, 'rejected', reasonController.text.trim());
              },
              child: const Text('TOLAK PERMINTAAN', style: TextStyle(fontSize: 12)),
            ),

            // Approve Action
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.textDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                _handleVerify(context, mr.id, 'approved', null);
              },
              child: const Text('SETUJUI & KELUARKAN BAHAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleVerify(BuildContext context, int id, String status, String? reason) async {
    final prodProvider = Provider.of<ProductionProvider>(context, listen: false);
    final result = await prodProvider.verifyMaterialRequest(id, status: status, rejectionReason: reason);

    if (context.mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Permintaan berhasil diproses.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal memproses permintaan.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prodProvider = Provider.of<ProductionProvider>(context);
    final pendingRequests = prodProvider.materialRequests.where((m) => m.status == 'pending').toList();
    final historyRequests = prodProvider.materialRequests.where((m) => m.status != 'pending').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Papan Verifikasi MR Gudang', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'PENDING VERIFIKASI'),
              Tab(text: 'RIWAYAT VERIFIKASI'),
            ],
          ),
        ),
        body: Stack(
          children: [
            const ChemicalParticleBackground(),
            prodProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    children: [
                      // Tab 1: Pending Verification
                      pendingRequests.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada permintaan bahan baku pending.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: pendingRequests.length,
                              itemBuilder: (context, index) {
                                final mr = pendingRequests[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.3)),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    title: Text(
                                      mr.productionOrder?.formula?.name ?? 'Produksi Kosmetik',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Target: ${mr.productionOrder?.targetQuantity ?? 0} kg (${mr.items.length} item)',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          ),
                                          Text(
                                            mr.code,
                                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primaryLight, size: 16),
                                    onTap: () => _showVerificationDialog(context, mr),
                                  ),
                                );
                              },
                            ),

                      // Tab 2: Verification History
                      historyRequests.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada riwayat verifikasi.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: historyRequests.length,
                              itemBuilder: (context, index) {
                                final mr = historyRequests[index];
                                final isApproved = mr.status == 'approved';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.1)),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    title: Text(
                                      mr.productionOrder?.formula?.name ?? 'Produksi Kosmetik',
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Target: ${mr.productionOrder?.targetQuantity ?? 0} kg',
                                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                              ),
                                              Text(
                                                mr.code,
                                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                                              ),
                                            ],
                                          ),
                                          if (mr.rejectionReason != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Alasan Tolak: "${mr.rejectionReason}"',
                                              style: const TextStyle(color: AppColors.error, fontSize: 11, fontStyle: FontStyle.italic),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isApproved ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        mr.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: isApproved ? AppColors.success : AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
