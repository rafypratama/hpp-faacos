import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/formatter.dart';
import '../../providers/inventory_provider.dart';
import '../../models/ingredient_model.dart';
import '../widgets/chemical_particle_background.dart';

class InventoryScreen extends StatefulWidget {
  final bool isReadOnly;
  const InventoryScreen({super.key, this.isReadOnly = false});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).fetchIngredients();
      Provider.of<InventoryProvider>(context, listen: false).fetchLogs();
    });
  }

  void _showAddIngredientDialog(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();

    final codeController = TextEditingController();
    final nameController = TextEditingController();
    String selectedType = 'raw_material'; // raw_material, packaging
    String selectedUnit = 'kg'; // g, kg, ml, l, pcs
    final priceController = TextEditingController();
    final qtyController = TextEditingController();
    final minStockController = TextEditingController();
    final expiredAtController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.add_business_rounded, color: AppColors.secondary, size: 24),
              SizedBox(width: 8),
              Text(
                'Penerimaan Bahan Baru',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code
                    TextFormField(
                      controller: codeController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Kode Bahan (contoh: RAW-006)',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Kode wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Nama Bahan Baku / Kemasan',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Type
                    DropdownButtonFormField<String>(
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      dropdownColor: AppColors.surface,
                      decoration: const InputDecoration(labelText: 'Jenis Bahan'),
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'raw_material', child: Text('Bahan Baku (Raw Material)')),
                        DropdownMenuItem(value: 'packaging', child: Text('Bahan Kemasan (Packaging)')),
                      ],
                      onChanged: (val) {
                        if (val != null) selectedType = val;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Unit
                    DropdownButtonFormField<String>(
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      dropdownColor: AppColors.surface,
                      decoration: const InputDecoration(labelText: 'Satuan Standar'),
                      value: selectedUnit,
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('gram (g)')),
                        DropdownMenuItem(value: 'kg', child: Text('kilogram (kg)')),
                        DropdownMenuItem(value: 'ml', child: Text('mililiter (ml)')),
                        DropdownMenuItem(value: 'l', child: Text('Liter (l)')),
                        DropdownMenuItem(value: 'pcs', child: Text('pieces (pcs)')),
                      ],
                      onChanged: (val) {
                        if (val != null) selectedUnit = val;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price per Unit
                    TextFormField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Harga per Satuan (Rp)',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Harga wajib diisi';
                        final parsed = double.tryParse(val);
                        if (parsed == null || parsed < 0) return 'Harga tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Quantity (Newly Arrived Stock)
                    TextFormField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Kuantitas (Baru Datang)',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        helperText: 'Jumlah ini otomatis digabungkan jika kode/nama bahan sudah ada.',
                        helperStyle: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Jumlah kuantitas wajib diisi';
                        final parsed = double.tryParse(val);
                        if (parsed == null || parsed < 0) return 'Kuantitas tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                     // Minimum Stock level (warning)
                    TextFormField(
                      controller: minStockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Batas Minimum Stok (Peringatan)',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final parsed = double.tryParse(val);
                          if (parsed == null || parsed < 0) return 'Batas tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Expiration Date Selection (Optional)
                    TextFormField(
                      controller: expiredAtController,
                      readOnly: true,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Kadaluarsa (Optional)',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        suffixIcon: Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColors.primary,
                                  onPrimary: AppColors.textPrimary,
                                  surface: AppColors.surface,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          expiredAtController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('BATAL', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(context).pop();

                final double minStock = minStockController.text.isNotEmpty 
                    ? double.parse(minStockController.text) 
                    : 0.0;

                final result = await inventory.addIngredient(
                  code: codeController.text.trim(),
                  name: nameController.text.trim(),
                  type: selectedType,
                  unit: selectedUnit,
                  pricePerUnit: double.parse(priceController.text),
                  currentStock: double.parse(qtyController.text),
                  minimumStock: minStock,
                  expiredAt: expiredAtController.text.isNotEmpty ? expiredAtController.text : null,
                );

                if (context.mounted) {
                  if (result['success']) {
                    final bool merged = result['merged'] ?? false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          merged 
                              ? 'Bahan sudah terdaftar! Stok baru otomatis ditambahkan ke sisa stok lama.' 
                              : 'Bahan baru berhasil didaftarkan.',
                        ),
                        backgroundColor: merged ? AppColors.warning : AppColors.success,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Gagal mendaftarkan bahan baru.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('TERIMA BAHAN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAdjustmentDialog(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();

    IngredientModel? selectedIng;
    String selectedType = 'in'; // in, out, adjustment
    final qtyController = TextEditingController();
    String selectedUnit = 'kg';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: const [
              Icon(Icons.inventory_2_rounded, color: AppColors.primaryLight, size: 24),
              SizedBox(width: 8),
              Text(
                'Penyesuaian Stok Manual',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Select Ingredient
                    DropdownButtonFormField<IngredientModel>(
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      dropdownColor: AppColors.surface,
                      decoration: const InputDecoration(labelText: 'Pilih Bahan Baku / Kemasan'),
                      items: inventory.ingredients.map((ing) {
                        return DropdownMenuItem<IngredientModel>(
                          value: ing,
                          child: Text('${ing.name} (${ing.code})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        selectedIng = val;
                        if (val != null) {
                          setState(() => selectedUnit = val.unit);
                        }
                      },
                      validator: (val) => val == null ? 'Pilih bahan baku' : null,
                    ),
                    const SizedBox(height: 16),

                    // Select Type
                    DropdownButtonFormField<String>(
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      dropdownColor: AppColors.surface,
                      decoration: const InputDecoration(labelText: 'Jenis Penyesuaian'),
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'in', child: Text('Stock In (Penerimaan Bahan Baru)')),
                        DropdownMenuItem(value: 'out', child: Text('Stock Out (Kerusakan / Kedaluwarsa)')),
                        DropdownMenuItem(value: 'adjustment', child: Text('Stock Opname (Penyesuaian Fisik)')),
                      ],
                      onChanged: (val) {
                        if (val != null) selectedType = val;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Quantity & Unit
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(labelText: 'Jumlah Nominal'),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Kuantitas wajib diisi';
                              if (double.tryParse(val) == null || double.tryParse(val)! <= 0) return 'Must be gt 0';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            style: const TextStyle(color: AppColors.primaryLight, fontSize: 12),
                            dropdownColor: AppColors.surface,
                            decoration: const InputDecoration(labelText: 'Satuan'),
                            value: selectedUnit,
                            items: const [
                              DropdownMenuItem(value: 'g', child: Text('gram')),
                              DropdownMenuItem(value: 'kg', child: Text('kg')),
                              DropdownMenuItem(value: 'ml', child: Text('ml')),
                              DropdownMenuItem(value: 'l', child: Text('Liter')),
                              DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                            ],
                            onChanged: (val) {
                              if (val != null) selectedUnit = val;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: notesController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Catatan Rincian Penyesuaian',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('BATAL', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(context).pop();

                final result = await inventory.adjustStock(
                  ingredientId: selectedIng!.id,
                  type: selectedType,
                  quantity: double.parse(qtyController.text),
                  unit: selectedUnit,
                  notes: notesController.text.trim(),
                );

                if (context.mounted) {
                  if (result['success']) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'] ?? 'Stok berhasil disesuaikan.'), backgroundColor: AppColors.success),
                    );
                    inventory.fetchIngredients();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'] ?? 'Gagal menyesuaikan stok.'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('SUBMIT DATA', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Kontrol Persediaan & Log Mutasi', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'PERSEDIAAN AKTUAL'),
              Tab(text: 'HISTORI LOG MUTASI'),
            ],
          ),
        ),
        body: Stack(
          children: [
            const ChemicalParticleBackground(),
            inventory.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    children: [
                  // Tab 1: Current Stocks
                  inventory.ingredients.isEmpty
                      ? const Center(child: Text('Stok gudang kosong.', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: inventory.ingredients.length,
                          itemBuilder: (context, index) {
                            final ing = inventory.ingredients[index];
                            final isRaw = ing.type == 'raw_material';

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
                                        ing.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isRaw ? AppColors.primary.withOpacity(0.1) : AppColors.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isRaw ? 'BAHAN BAKU' : 'KEMASAN',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: isRaw ? AppColors.primaryLight : AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
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
                                            'Harga Master: ${AppFormatter.formatCurrency(ing.pricePerUnit)} / ${ing.unit}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          ),
                                          Text(
                                            ing.code,
                                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                                          ),
                                        ],
                                      ),
                                      if (ing.expiredAt != null) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.event_note_rounded,
                                              size: 14,
                                              color: ing.expiredAt!.isBefore(DateTime.now())
                                                  ? AppColors.error
                                                  : ing.expiredAt!.isBefore(DateTime.now().add(const Duration(days: 30)))
                                                      ? AppColors.warning
                                                      : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Kadaluarsa: ${AppFormatter.formatDate(ing.expiredAt!)}',
                                              style: TextStyle(
                                                color: ing.expiredAt!.isBefore(DateTime.now())
                                                    ? AppColors.error
                                                    : ing.expiredAt!.isBefore(DateTime.now().add(const Duration(days: 30)))
                                                        ? AppColors.warning
                                                        : AppColors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: ing.expiredAt!.isBefore(DateTime.now().add(const Duration(days: 30)))
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            if (ing.expiredAt!.isBefore(DateTime.now())) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'EXPIRED',
                                                  style: TextStyle(color: AppColors.error, fontSize: 8, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ] else if (ing.expiredAt!.isBefore(DateTime.now().add(const Duration(days: 30)))) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppColors.warning.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'SEGERA EXPIRED',
                                                  style: TextStyle(color: AppColors.warning, fontSize: 8, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                trailing: Text(
                                  AppFormatter.formatQuantity(ing.currentStock, ing.unit),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                  // Tab 2: Mutation Movement Logs
                  inventory.logs.isEmpty
                      ? const Center(child: Text('Belum ada log mutasi.', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: inventory.logs.length,
                          itemBuilder: (context, index) {
                            final log = inventory.logs[index];

                            Color typeColor = AppColors.textMuted;
                            String typeSign = '';
                            if (log.type == 'in' || log.type == 'opname_in') {
                              typeColor = AppColors.success;
                              typeSign = '+';
                            } else if (log.type == 'out' || log.type == 'production_release' || log.type == 'opname_out') {
                              typeColor = AppColors.error;
                              typeSign = '-';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.1)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        log.ingredient?.name ?? 'Mutasi Bahan Baku',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      '$typeSign ${log.quantity} ${log.unit}',
                                      style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
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
                                            'Tipe: ${log.type.toUpperCase()}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                          ),
                                          Text(
                                            AppFormatter.formatDate(log.createdAt),
                                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Saldo Akhir: ${log.balanceAfter} ${log.unit} • Oleh: ${log.userName ?? "System"}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                      if (log.notes != null && log.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Catatan: "${log.notes}"',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ],
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
        floatingActionButton: widget.isReadOnly
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'btnAddIngredient',
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.textPrimary,
                      onPressed: () => _showAddIngredientDialog(context),
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('TERIMA BAHAN BARU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton.extended(
                      heroTag: 'btnAdjustStock',
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      onPressed: () => _showAdjustmentDialog(context),
                      icon: const Icon(Icons.compare_arrows_rounded),
                      label: const Text('SESUAIKAN STOK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
