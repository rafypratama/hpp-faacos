import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/formatter.dart';
import '../../providers/formula_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/formula_model.dart';
import '../../models/ingredient_model.dart';
import '../widgets/chemical_particle_background.dart';

class CostingSimulatorScreen extends StatefulWidget {
  const CostingSimulatorScreen({super.key});

  @override
  State<CostingSimulatorScreen> createState() => _CostingSimulatorScreenState();
}

class _CostingSimulatorScreenState extends State<CostingSimulatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FormulaProvider>(context, listen: false).fetchFormulas();
      Provider.of<InventoryProvider>(context, listen: false).fetchIngredients();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formulaProvider = Provider.of<FormulaProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cost & Sell',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              'The Essence of Noble Beauty',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryLight),
            tooltip: 'Refresh Data',
            onPressed: () {
              formulaProvider.fetchFormulas();
              Provider.of<InventoryProvider>(context, listen: false).fetchIngredients();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryLight,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Perhitungan Baru'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: Stack(
        children: [
          const ChemicalParticleBackground(),
          formulaProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _FormulaCreatorWidget(onDone: () {
                      _tabController.animateTo(1);
                      formulaProvider.fetchFormulas();
                    }),
                    const _FormulaListWidget(),
                  ],
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 1. FORMULA LIST WIDGET (RIWAYAT)
// ---------------------------------------------------------
class _FormulaListWidget extends StatelessWidget {
  const _FormulaListWidget();

  void _showFormulaDetails(BuildContext context, FormulaModel formula) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formula.code,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              formula.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: formula.status == 'approved'
                              ? AppColors.success.withOpacity(0.15)
                              : AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          formula.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: formula.status == 'approved'
                                ? AppColors.success
                                : AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, color: AppColors.surfaceElevated),

                  // Standard HPP Info Card
                  if (formula.hpp != null) ...[
                    Text(
                      'Rincian Biaya HPP (Jumlah: ${AppFormatter.formatQuantity(formula.batchSize, 'pcs')})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildCostRow('Biaya Bahan Baku', formula.hpp!.totalIngredientCost),
                          _buildCostRow('Biaya Kemasan', formula.hpp!.totalOverheadCost),
                          _buildCostRow('Biaya Produksi (10%)', formula.hpp!.totalLaborCost),
                          const Divider(color: AppColors.surfaceElevated),
                          _buildCostRow(
                            'Total HPP Produksi',
                            formula.hpp!.totalHpp,
                            isBold: true,
                            color: AppColors.primaryLight,
                          ),
                          _buildCostRow(
                            'Margin (${formula.hpp!.profitMarginPercent.round()}%)',
                            formula.hpp!.hppPerUnit * formula.hpp!.profitMarginPercent / 100 * formula.batchSize,
                          ),
                          _buildCostRow(
                            'PPN (11%)',
                            (formula.hpp!.totalHpp + (formula.hpp!.hppPerUnit * formula.hpp!.profitMarginPercent / 100 * formula.batchSize)) * 0.11,
                          ),
                          _buildCostRow(
                            'Harga Jual Total',
                            formula.hpp!.sellingPrice * formula.batchSize,
                            isBold: true,
                            color: AppColors.secondary,
                          ),
                          const Divider(color: AppColors.surfaceElevated),
                          _buildCostRow(
                            'HARGA PER PCS',
                            formula.hpp!.sellingPrice,
                            isBold: true,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Ingredients List Table
                  const Text(
                    'Bahan Baku & Kemasan',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: formula.ingredients.length,
                    itemBuilder: (context, index) {
                      final item = formula.ingredients[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.surfaceElevated, width: 0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.ingredient?.name ?? 'Bahan Baku',
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                  ),
                                  Text(
                                    '${AppFormatter.formatQuantity(item.quantityPerBatch, item.unit)} @ ${AppFormatter.formatCurrency(item.unitPrice)} per unit gudang',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              AppFormatter.formatCurrency(item.subtotal),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Actions: ACC Button
                  if (formula.status == 'draft') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('ACC / SETUJUI FORMULA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.textDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          _handleApproveFormula(context, formula);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCostRow(String title, double value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          Text(
            AppFormatter.formatCurrency(value),
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApproveFormula(BuildContext context, FormulaModel formula) async {
    final formulaProvider = Provider.of<FormulaProvider>(context, listen: false);
    final result = await formulaProvider.approveFormula(formula.id);

    if (context.mounted) {
      if (result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Formula berhasil disetujui.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (result['status'] == 'insufficient_stock') {
        _showShortageDialog(context, formula.name, result['shortages']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Terjadi kesalahan approval.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showShortageDialog(BuildContext context, String formulaName, List shortages) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
              SizedBox(width: 12),
              Text(
                'PERINGATAN STOK KURANG',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
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
                Text(
                  'Stok bahan baku di gudang tidak mencukupi untuk melakukan ACC formula "$formulaName".',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Detail Kekurangan Bahan Baku:',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: shortages.length,
                    itemBuilder: (context, index) {
                      final s = shortages[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name'] ?? 'Bahan Baku',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kebutuhan: ${s['required_quantity']} ${s['required_unit']}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                                Text(
                                  'Tersedia: ${s['available_stock']} ${s['required_unit']}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                            const Divider(color: AppColors.surfaceElevated, height: 12),
                            Text(
                              'Kekurangan: ${s['shortage_quantity']} ${s['shortage_unit']} (${s['shortage_in_master']} ${s['master_unit']})',
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sistem otomatis mengirimkan notifikasi permintaan restock ke Kepala Gudang & Admin.',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 11, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
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

  @override
  Widget build(BuildContext context) {
    final formulaProvider = Provider.of<FormulaProvider>(context);

    if (formulaProvider.formulas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.biotech_rounded, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(
              'Belum ada riwayat perhitungan.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: formulaProvider.formulas.length,
      itemBuilder: (context, index) {
        final f = formulaProvider.formulas[index];
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
                    f.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: f.status == 'approved'
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    f.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: f.status == 'approved' ? AppColors.success : AppColors.primaryLight,
                    ),
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
                    'Harga/Pcs: ${f.hpp != null ? AppFormatter.formatCurrency(f.hpp!.sellingPrice) : "-"}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  Text(
                    f.code,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            onTap: () => _showFormulaDetails(context, f),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// 2. FORMULA CREATOR WIDGET (PERHITUNGAN BARU)
// ---------------------------------------------------------
class _FormulaCreatorWidget extends StatefulWidget {
  final VoidCallback onDone;

  const _FormulaCreatorWidget({required this.onDone});

  @override
  State<_FormulaCreatorWidget> createState() => _FormulaCreatorWidgetState();
}

class _FormulaCreatorWidgetState extends State<_FormulaCreatorWidget> {
  final _formKey = GlobalKey<FormState>();
  
  // Text Controllers matching Screenshots
  final _nameController = TextEditingController();
  final _packagingController = TextEditingController(text: '0');
  final _qtyController = TextEditingController(text: '1');
  
  double _profitMargin = 100.0;

  // Selected ingredients
  final List<Map<String, dynamic>> _selectedIngredients = [];

  @override
  void dispose() {
    _nameController.dispose();
    _packagingController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  // Live real-time HPP math helper
  double _calculateLiveTotalIngredientCost() {
    double total = 0.0;
    for (var item in _selectedIngredients) {
      if (item['ingredient'] != null) {
        final ing = item['ingredient'] as IngredientModel;
        final qty = item['quantity'] as double;
        final unit = item['unit'] as String;

        double qtyInMaster = qty;
        if (unit == 'g' && ing.unit == 'kg') {
          qtyInMaster = qty / 1000.0;
        } else if (unit == 'kg' && ing.unit == 'g') {
          qtyInMaster = qty * 1000.0;
        } else if (unit == 'ml' && ing.unit == 'l') {
          qtyInMaster = qty / 1000.0;
        } else if (unit == 'l' && ing.unit == 'ml') {
          qtyInMaster = qty * 1000.0;
        }

        total += qtyInMaster * ing.pricePerUnit;
      }
    }
    return total;
  }

  double _getPackagingCost() => double.tryParse(_packagingController.text) ?? 0.0;
  double _getQuantity() => double.tryParse(_qtyController.text) ?? 1.0;

  void _addNewIngredientRow(IngredientModel ing) {
    setState(() {
      _selectedIngredients.add({
        'ingredient': ing,
        'quantity': 1.0,
        'unit': ing.unit,
      });
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal 1 bahan baku ke dalam formula.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final formulaProvider = Provider.of<FormulaProvider>(context, listen: false);

    // Map ingredients to save payload format
    final ingredientsPayload = _selectedIngredients.map((i) {
      final ing = i['ingredient'] as IngredientModel;
      return {
        'ingredient_id': ing.id,
        'quantity': i['quantity'],
        'unit': i['unit'],
      };
    }).toList();

    // Map Packaging as Overhead, Production Cost as Labor to align with backend db math!
    final liveIngredientsSubtotal = _calculateLiveTotalIngredientCost();
    final packagingCost = _getPackagingCost();
    final productionCost = 0.10 * (liveIngredientsSubtotal + packagingCost);

    final costsPayload = [
      {'type': 'labor', 'description': 'Biaya Produksi (10%)', 'cost_value': productionCost},
      {'type': 'overhead', 'description': 'Biaya Kemasan', 'cost_value': packagingCost},
      {'type': 'other', 'description': 'Biaya Lain-lain', 'cost_value': 0.0},
    ];

    final result = await formulaProvider.saveFormula(
      name: _nameController.text.trim(),
      batchSize: _getQuantity(),
      ingredients: ingredientsPayload,
      costs: costsPayload,
      profitMarginPercent: _profitMargin,
    );

    if (context.mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perhitungan costing formula berhasil disimpan.'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onDone();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal menyimpan formula.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context);

    // Live Dynamic Math
    final liveIngredientsSubtotal = _calculateLiveTotalIngredientCost();
    final packagingCost = _getPackagingCost();
    
    // Biaya Produksi (10% of total ingredients + packaging)
    final liveProductionCost = 0.10 * (liveIngredientsSubtotal + packagingCost);
    
    // Total HPP
    final liveTotalHpp = liveIngredientsSubtotal + packagingCost + liveProductionCost;
    
    // Margin (Profit)
    final liveMarginValue = liveTotalHpp * (_profitMargin / 100);
    
    // PPN 11% (from HPP + Margin)
    final livePpn = (liveTotalHpp + liveMarginValue) * 0.11;
    
    // Harga Jual
    final liveSellingPrice = liveTotalHpp + liveMarginValue + livePpn;
    
    // Harga Per Pcs
    final livePricePerPcs = liveSellingPrice / _getQuantity();

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CARD: Informasi Produk
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Produk',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Nama Produk',
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(right: 12, left: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primaryLight, size: 20),
                      ),
                      isDense: true,
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Nama produk wajib diisi' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. CARD: Bahan Baku
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bahan Baku',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      PopupMenuButton<IngredientModel>(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: AppColors.primaryLight, size: 20),
                        ),
                        tooltip: 'Tambah bahan baku',
                        onSelected: _addNewIngredientRow,
                        itemBuilder: (context) {
                          return inventory.ingredients.map((ing) {
                            return PopupMenuItem<IngredientModel>(
                              value: ing,
                              child: Text('${ing.name} (${ing.code})'),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedIngredients.isEmpty) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: const [
                            Icon(Icons.assignment_turned_in_rounded, color: AppColors.textMuted, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'Belum ada bahan baku',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap tombol + untuk menambah',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedIngredients.length,
                      itemBuilder: (context, index) {
                        final row = _selectedIngredients[index];
                        final ing = row['ingredient'] as IngredientModel;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ing.name,
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@ ${AppFormatter.formatCurrency(ing.pricePerUnit)} / ${ing.unit}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: row['quantity'].toString(),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                                  decoration: const InputDecoration(
                                    hintText: 'Qty',
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      row['quantity'] = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButton<String>(
                                  value: row['unit'],
                                  isDense: true,
                                  style: const TextStyle(color: AppColors.primaryLight, fontSize: 12),
                                  dropdownColor: AppColors.surface,
                                  items: const [
                                    DropdownMenuItem(value: 'g', child: Text('gram')),
                                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                                    DropdownMenuItem(value: 'ml', child: Text('ml')),
                                    DropdownMenuItem(value: 'l', child: Text('Liter')),
                                    DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => row['unit'] = val);
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 20),
                                onPressed: () {
                                  setState(() => _selectedIngredients.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. CARD: Ringkasan Perhitungan
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan Perhitungan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Total Bahan Baku Row
                  _buildLiveRow('Total Bahan Baku', liveIngredientsSubtotal),
                  const Divider(color: AppColors.surfaceElevated, height: 20),

                  // Biaya Kemasan Input
                  TextFormField(
                    controller: _packagingController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Biaya Kemasan',
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(right: 12, left: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryLight, size: 20),
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                  const Divider(color: AppColors.surfaceElevated, height: 20),

                  // Biaya Produksi (10%) Row
                  _buildLiveRow('Biaya Produksi (10%)', liveProductionCost),
                  const Divider(color: AppColors.surfaceElevated, height: 20),

                  // TOTAL HPP Row
                  _buildLiveRow('TOTAL HPP', liveTotalHpp, isBold: true, color: AppColors.primaryLight),
                  const Divider(color: AppColors.surfaceElevated, height: 20),

                  // Margin (X%) Row & Slider
                  _buildLiveRow('Margin (${_profitMargin.round()}%)', liveMarginValue),
                  const SizedBox(height: 8),
                  Slider(
                    value: _profitMargin,
                    min: 0,
                    max: 200,
                    activeColor: AppColors.primaryLight,
                    inactiveColor: AppColors.surfaceElevated,
                    onChanged: (val) => setState(() => _profitMargin = val),
                  ),
                  const Divider(color: AppColors.surfaceElevated, height: 20),

                  // PPN (11%) Row
                  _buildLiveRow('PPN (11%)', livePpn),
                  const Divider(color: AppColors.surfaceElevated, height: 20),

                  // HARGA JUAL Row
                  _buildLiveRow('HARGA JUAL', liveSellingPrice, isBold: true, color: AppColors.secondary),
                  const Divider(color: AppColors.surfaceElevated, height: 20),

                  // Jumlah Produksi (pcs) Input
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Jumlah Produksi (pcs)',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(right: 12, left: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_cart_outlined, color: AppColors.primaryLight, size: 20),
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  // Harga Per Pcs Box (Green/Success outlined/filled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'HARGA PER PCS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          AppFormatter.formatCurrency(livePricePerPcs.isInfinite || livePricePerPcs.isNaN ? 0.0 : livePricePerPcs),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. ACTION BUTTONS: Simpan, Cetak, Export PDF
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, color: AppColors.textDark),
                label: const Text(
                  'Simpan Perhitungan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _handleSubmit,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print_rounded, color: AppColors.textPrimary, size: 18),
                      label: const Text('Cetak', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.surfaceElevated.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Menyiapkan printer...'),
                            backgroundColor: AppColors.info,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.textPrimary, size: 18),
                      label: const Text('Export PDF', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.surfaceElevated.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mengekspor file PDF...'),
                            backgroundColor: AppColors.info,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveRow(String title, double val, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 12.5,
          ),
        ),
        Text(
          AppFormatter.formatCurrency(val),
          style: TextStyle(
            color: color ?? AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

