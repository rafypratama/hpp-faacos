import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/formatter.dart';
import '../../providers/production_provider.dart';
import '../../providers/formula_provider.dart';
import '../../models/production_order_model.dart';
import '../../models/formula_model.dart';
import '../widgets/chemical_particle_background.dart';

class ProductionSchedulerScreen extends StatefulWidget {
  const ProductionSchedulerScreen({super.key});

  @override
  State<ProductionSchedulerScreen> createState() => _ProductionSchedulerScreenState();
}

class _ProductionSchedulerScreenState extends State<ProductionSchedulerScreen> {
  bool _isSchedulingNew = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductionProvider>(context, listen: false).fetchProductionOrders();
      Provider.of<FormulaProvider>(context, listen: false).fetchFormulas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prodProvider = Provider.of<ProductionProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _isSchedulingNew ? 'Buat Jadwal Produksi Baru' : 'Jadwal Rencana Produksi',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isSchedulingNew) {
              setState(() => _isSchedulingNew = false);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Stack(
        children: [
          const ChemicalParticleBackground(),
          prodProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _isSchedulingNew
                  ? _OrderSchedulerWidget(onDone: () {
                      setState(() => _isSchedulingNew = false);
                      prodProvider.fetchProductionOrders();
                    })
                  : _OrderListWidget(onScheduleNewTap: () {
                      setState(() => _isSchedulingNew = true);
                    }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 1. PRODUCTION ORDER LIST
// ---------------------------------------------------------
class _OrderListWidget extends StatelessWidget {
  final VoidCallback onScheduleNewTap;

  const _OrderListWidget({required this.onScheduleNewTap});

  void _showOrderDetail(BuildContext context, ProductionOrderModel order) {
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
                order.code,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace'),
              ),
              Text(
                order.formula?.name ?? 'Produksi Kosmetik',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Ukuran Target Produksi:', '${order.targetQuantity} kg / L'),
                _buildInfoRow('Jumlah Batch:', '${order.batchCount} batch'),
                _buildInfoRow('Status Produksi:', order.status.toUpperCase(), isStatus: true),
                _buildInfoRow(
                  'Tanggal Mulai:',
                  order.scheduledStartDate != null ? AppFormatter.formatDate(order.scheduledStartDate!) : 'Belum dijadwalkan',
                ),
                const Divider(color: AppColors.surfaceElevated, height: 24),
                
                // Associated auto-generated Material Request
                if (order.materialRequest != null) ...[
                  const Text(
                    'Permintaan Bahan Baku (Material Request)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.materialRequest!.code,
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${order.materialRequest!.status.toUpperCase()}',
                              style: TextStyle(
                                color: order.materialRequest!.status == 'approved'
                                    ? AppColors.success
                                    : order.materialRequest!.status == 'rejected'
                                        ? AppColors.error
                                        : AppColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (order.materialRequest!.status == 'rejected') ...[
                          const Icon(Icons.cancel_rounded, color: AppColors.error),
                        ] else if (order.materialRequest!.status == 'approved') ...[
                          const Icon(Icons.check_circle_rounded, color: AppColors.success),
                        ] else ...[
                          const Icon(Icons.hourglass_empty_rounded, color: AppColors.warning),
                        ]
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('TUTUP', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String val, {bool isStatus = false}) {
    Color? valColor;
    if (isStatus) {
      if (val == 'IN_PRODUCTION') valColor = AppColors.info;
      if (val == 'MATERIAL_REQUESTED') valColor = AppColors.warning;
      if (val == 'SCHEDULED') valColor = AppColors.primaryLight;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(
            val,
            style: TextStyle(
              color: valColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prodProvider = Provider.of<ProductionProvider>(context);

    if (prodProvider.productionOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Belum ada jadwal rencana produksi.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Jadwalkan Produksi Baru'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onScheduleNewTap,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: prodProvider.productionOrders.length,
          itemBuilder: (context, index) {
            final po = prodProvider.productionOrders[index];

            Color statusColor = AppColors.textMuted;
            if (po.status == 'in_production') statusColor = AppColors.info;
            if (po.status == 'material_requested') statusColor = AppColors.warning;
            if (po.status == 'scheduled') statusColor = AppColors.primaryLight;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.3)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        po.formula?.name ?? 'Produksi Kosmetik',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        po.status.toUpperCase(),
                        style: TextStyle(fontSize: 8, color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target: ${po.targetQuantity} kg (${po.batchCount} batch)',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        po.code,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                onTap: () => _showOrderDetail(context, po),
              ),
            );
          },
        ),

        // FAB to schedule new order
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            onPressed: onScheduleNewTap,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// 2. CREATE NEW PRODUCTION ORDER WIDGET
// ---------------------------------------------------------
class _OrderSchedulerWidget extends StatefulWidget {
  final VoidCallback onDone;

  const _OrderSchedulerWidget({required this.onDone});

  @override
  State<_OrderSchedulerWidget> createState() => _OrderSchedulerWidgetState();
}

class _OrderSchedulerWidgetState extends State<_OrderSchedulerWidget> {
  final _formKey = GlobalKey<FormState>();
  FormulaModel? _selectedFormula;
  final _targetQtyController = TextEditingController();
  final _batchCountController = TextEditingController(text: '1');
  final _startDateController = TextEditingController(text: DateTime.now().toString().substring(0, 10));

  @override
  void dispose() {
    _targetQtyController.dispose();
    _batchCountController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFormula == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wajib memilih formula kosmetik.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final prodProvider = Provider.of<ProductionProvider>(context, listen: false);

    final result = await prodProvider.scheduleProduction(
      formulaId: _selectedFormula!.id,
      targetQuantity: double.parse(_targetQtyController.text),
      batchCount: int.parse(_batchCountController.text),
      scheduledStartDate: _startDateController.text,
      scheduledEndDate: _startDateController.text, // default same day
    );

    if (context.mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rencana produksi berhasil dijadwalkan dan Material Request telah digenerate.'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onDone();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal menjadwalkan produksi.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formulaProvider = Provider.of<FormulaProvider>(context);
    final approvedFormulas = formulaProvider.formulas.where((f) => f.status == 'approved').toList();

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Select Formula
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonFormField<FormulaModel>(
                value: _selectedFormula,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                  labelText: 'Pilih Formula APPROVED R&D',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                ),
                items: approvedFormulas.map((f) {
                  return DropdownMenuItem<FormulaModel>(
                    value: f,
                    child: Text('${f.name} (${f.code})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedFormula = val;
                    if (val != null) {
                      _targetQtyController.text = val.batchSize.toString();
                    }
                  });
                },
                validator: (val) => val == null ? 'Pilih formula' : null,
              ),
            ),
            const SizedBox(height: 20),

            // Target Quantity & Batches info
            if (_selectedFormula != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.info.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimasi Pengeluaran Bahan Baku (Live Scale)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    // Live scaling factor display
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedFormula!.ingredients.length,
                      itemBuilder: (context, index) {
                        final ing = _selectedFormula!.ingredients[index];
                        final targetQty = double.tryParse(_targetQtyController.text) ?? _selectedFormula!.batchSize;
                        final scale = targetQty / _selectedFormula!.batchSize;
                        final estimatedReq = ing.quantityPerBatch * scale;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(ing.ingredient?.name ?? 'Bahan Baku', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              Text(
                                '${estimatedReq.toStringAsFixed(2)} ${ing.unit}',
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Input Fields
            TextFormField(
              controller: _targetQtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Target Jumlah Produksi (kg / L)'),
              onChanged: (val) => setState(() {}),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Target wajib diisi';
                if (double.tryParse(val) == null || double.tryParse(val)! <= 0) return 'Must be gt 0';
                return null;
              },
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _batchCountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Jumlah Batch Produksi'),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Jumlah batch wajib diisi';
                if (int.tryParse(val) == null || int.tryParse(val)! <= 0) return 'Must be gt 0';
                return null;
              },
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _startDateController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Tanggal Mulai Rencana Produksi',
                suffixIcon: Icon(Icons.date_range, color: AppColors.textMuted),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Tanggal rencana wajib diisi' : null,
            ),
            const SizedBox(height: 48),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('AJUKAN JADWAL & MR SEKARANG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
