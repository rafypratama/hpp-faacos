import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import '../core/network/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/realtime_notification_provider.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';

// Import R&D screen placeholders
import 'rnd/costing_simulator_screen.dart';
import 'gudang/inventory_screen.dart';
import 'gudang/mr_verification_screen.dart';
import 'produksi/production_scheduler_screen.dart';
import 'admin/user_management_screen.dart';
import 'widgets/chemical_particle_background.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isStatsLoading = true;
  int _totalIngredients = 0;
  int _totalPerhitungan = 0;
  int _bahanExpired = 0;
  int _segeraExpired = 0;
  bool _hasShownExpiryWarning = false;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      if (user != null) {
        Provider.of<RealtimeNotificationProvider>(context, listen: false)
            .initialize(context, user.email);
      }

      // Initialize offline auto-sync service
      SyncService().initialize(context);
    });
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() {
      _isStatsLoading = true;
    });
    try {
      final response = await ApiClient().dio.get('/dashboard');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final metrics = response.data['data']['metrics'];
        final expiredList = response.data['data']['expired_ingredients'] as List?;
        final nearExpiryList = response.data['data']['near_expiry_ingredients'] as List?;
        
        if (mounted) {
          setState(() {
            _totalIngredients = metrics['total_ingredients'] ?? 0;
            _totalPerhitungan = metrics['total_formulas'] ?? 0;
            _bahanExpired = metrics['expired_count'] ?? 0;
            _segeraExpired = metrics['near_expiry_count'] ?? 0;
            _isStatsLoading = false;
          });

          // Automatically trigger dialog if we have expired or near expiry ingredients and user is admin or kepala_gudang
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final user = authProvider.user;
          if (user != null && (user.role == 'admin' || user.role == 'kepala_gudang')) {
            if (!_hasShownExpiryWarning && 
                ((expiredList != null && expiredList.isNotEmpty) || 
                 (nearExpiryList != null && nearExpiryList.isNotEmpty))) {
              _hasShownExpiryWarning = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showExpiryWarningDialog(expiredList ?? [], nearExpiryList ?? []);
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStatsLoading = false;
        });
      }
    }
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    String badgeText;

    switch (role) {
      case 'admin':
        badgeColor = AppColors.accent;
        badgeText = 'Administrator';
        break;
      case 'rnd':
        badgeColor = AppColors.primaryLight;
        badgeText = 'R&D Specialist';
        break;
      case 'kepala_produksi':
        badgeColor = AppColors.warning;
        badgeText = 'Kepala Produksi';
        break;
      case 'kepala_gudang':
        badgeColor = AppColors.secondary;
        badgeText = 'Kepala Gudang';
        break;
      default:
        badgeColor = AppColors.textMuted;
        badgeText = 'Karyawan';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        badgeText.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                        ),
                      )
                    : Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAccessDeniedDialog({
    required String menuName,
    required String allowedRoles,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.error.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gpp_bad_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Akses Dibatasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Peran Anda saat ini tidak memiliki hak akses untuk membuka menu "$menuName".',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hanya dapat diakses oleh:\n$allowedRoles',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.error, AppColors.warning],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'MENGERTI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpiryWarningDialog(List<dynamic> expiredList, List<dynamic> nearExpiryList) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.error.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peringatan Kadaluarsa!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ditemukan bahan baku kritis di gudang',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Scrollable Warning List
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Already Expired Section
                      if (expiredList.isNotEmpty) ...[
                        _buildExpiryDialogSectionHeader(
                          title: 'TELAH KADALUARSA (${expiredList.length} Bahan)',
                          color: AppColors.error,
                          icon: Icons.gpp_bad_rounded,
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: expiredList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = expiredList[index];
                            return _buildExpiryDialogItem(
                              name: item['name'] ?? '',
                              code: item['code'] ?? '',
                              date: item['expired_at'] ?? '',
                              stock: (item['current_stock'] ?? 0).toString(),
                              unit: item['unit'] ?? '',
                              isExpired: true,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Near Expiry Section
                      if (nearExpiryList.isNotEmpty) ...[
                        _buildExpiryDialogSectionHeader(
                          title: 'SEGERA KADALUARSA (${nearExpiryList.length} Bahan)',
                          color: AppColors.warning,
                          icon: Icons.hourglass_empty_rounded,
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: nearExpiryList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = nearExpiryList[index];
                            return _buildExpiryDialogItem(
                              name: item['name'] ?? '',
                              code: item['code'] ?? '',
                              date: item['expired_at'] ?? '',
                              stock: (item['current_stock'] ?? 0).toString(),
                              unit: item['unit'] ?? '',
                              isExpired: false,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.surfaceElevated.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'MENGERTI',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.error, AppColors.warning],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final role = authProvider.user?.role ?? '';
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => InventoryScreen(
                                isReadOnly: role == 'rnd' || role == 'admin',
                              ),
                            ),
                          ).then((_) => _fetchStats());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'TINJAU GUDANG',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryDialogSectionHeader({
    required String title,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryDialogItem({
    required String name,
    required String code,
    required String date,
    required String stock,
    required String unit,
    required bool isExpired,
  }) {
    final Color badgeColor = isExpired ? AppColors.error : AppColors.warning;
    String formattedDate = date;
    try {
      final parsedDate = DateTime.parse(date);
      formattedDate = "${parsedDate.day.toString().padLeft(2, '0')}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.year}";
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kode: $code | Stok: $stock $unit',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, color: badgeColor, size: 10),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          hoverColor: color.withOpacity(0.05),
          splashColor: color.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final role = user?.role ?? '';

    // Route items based on authorization roles - Now Unified (visible for all)
    final List<Widget> menuItems = [
      // 1. Cost & Sell HPP
      _buildMenuCard(
        context: context,
        title: 'Cost & Sell (HPP)',
        description: 'Rancang formula kosmetik, kalkulasi HPP real-time, dan ajukan persetujuan R&D.',
        icon: Icons.biotech_rounded,
        color: AppColors.primaryLight,
        onTap: () {
          if (role == 'rnd' || role == 'admin' || role == 'kepala_produksi') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CostingSimulatorScreen()),
            ).then((_) => _fetchStats());
          } else {
            _showAccessDeniedDialog(
              menuName: 'Cost & Sell (HPP)',
              allowedRoles: 'R&D Specialist, Kepala Produksi, Administrator',
            );
          }
        },
      ),

      // 2. Jadwal Produksi
      _buildMenuCard(
        context: context,
        title: 'Jadwal Produksi',
        description: 'Jadwalkan batch produksi baru dari formula APPROVED dan terbitkan permintaan bahan baku.',
        icon: Icons.calendar_today_rounded,
        color: AppColors.warning,
        onTap: () {
          if (role == 'kepala_produksi' || role == 'admin') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductionSchedulerScreen()),
            ).then((_) => _fetchStats());
          } else {
            _showAccessDeniedDialog(
              menuName: 'Jadwal Produksi',
              allowedRoles: 'Kepala Produksi, Administrator',
            );
          }
        },
      ),

      // 3. Verifikasi Permintaan
      _buildMenuCard(
        context: context,
        title: 'Verifikasi Permintaan',
        description: 'Verifikasi pengeluaran bahan baku (Material Request), kurangi stok, dan catat log mutasi.',
        icon: Icons.fact_check_rounded,
        color: AppColors.secondary,
        onTap: () {
          if (role == 'kepala_gudang' || role == 'admin') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MrVerificationScreen()),
            ).then((_) => _fetchStats());
          } else {
            _showAccessDeniedDialog(
              menuName: 'Verifikasi Permintaan',
              allowedRoles: 'Kepala Gudang, Administrator',
            );
          }
        },
      ),

      // 4. Gudang Bahan Baku
      _buildMenuCard(
        context: context,
        title: 'Gudang Bahan Baku',
        description: 'Kelola persediaan bahan baku / kemasan kosmetik, catat Stock In / Out, dan lakukan Stock Opname.',
        icon: Icons.inventory_2_rounded,
        color: AppColors.info,
        onTap: () {
          if (role == 'kepala_gudang' || role == 'rnd' || role == 'admin') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InventoryScreen(
                  isReadOnly: role == 'rnd' || role == 'admin',
                ),
              ),
            ).then((_) => _fetchStats());
          } else {
            _showAccessDeniedDialog(
              menuName: 'Gudang Bahan Baku',
              allowedRoles: 'Kepala Gudang, R&D Specialist, Administrator',
            );
          }
        },
      ),

      // 5. Manajemen Pengguna
      _buildMenuCard(
        context: context,
        title: 'Manajemen Pengguna',
        description: 'Kelola data karyawan (tambah, edit, hapus) serta otorisasi hak akses peran.',
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFFD97706),
        onTap: () {
          if (role == 'admin') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            ).then((_) => _fetchStats());
          } else {
            _showAccessDeniedDialog(
              menuName: 'Manajemen Pengguna',
              allowedRoles: 'Administrator',
            );
          }
        },
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'FAACHOSTHERA ERP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 1.0,
                fontSize: 15,
              ),
            ),
          ],
        ),
        actions: [
          // Pending sync badge
          ValueListenableBuilder<int>(
            valueListenable: SyncService().pendingCount,
            builder: (context, count, _) {
              if (count == 0) return const SizedBox.shrink();
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_upload_outlined, color: AppColors.warning, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryLight),
            tooltip: 'Refresh Statistik',
            onPressed: _fetchStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Logout',
            onPressed: () async {
              // Disconnect Pusher listener
              Provider.of<RealtimeNotificationProvider>(context, listen: false).disconnect();
              
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const ChemicalParticleBackground(),
          RefreshIndicator(
            onRefresh: _fetchStats,
            color: AppColors.primary,
            backgroundColor: AppColors.surface.withOpacity(0.85),
            child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee Profile Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.surface,
                        AppColors.surface.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.surfaceElevated.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryLight.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Pengguna',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildRoleBadge(role),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Statistik Section Title
                const Text(
                  'Analisis & Statistik Gudang',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // 4 Stat Cards Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 900
                      ? 4
                      : MediaQuery.of(context).size.width > 550
                          ? 2
                          : 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.8,
                  children: [
                    _buildStatCard(
                      title: 'Total Bahan Baku',
                      value: '$_totalIngredients',
                      icon: Icons.inventory_2_rounded,
                      color: AppColors.info,
                      isLoading: _isStatsLoading,
                    ),
                    _buildStatCard(
                      title: 'Total Perhitungan',
                      value: '$_totalPerhitungan',
                      icon: Icons.calculate_rounded,
                      color: AppColors.secondary,
                      isLoading: _isStatsLoading,
                    ),
                    _buildStatCard(
                      title: 'Bahan Expired',
                      value: '$_bahanExpired',
                      icon: Icons.gpp_bad_rounded,
                      color: AppColors.error,
                      isLoading: _isStatsLoading,
                    ),
                    _buildStatCard(
                      title: 'Segera Expired',
                      value: '$_segeraExpired',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      isLoading: _isStatsLoading,
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Title Section
                const Text(
                  'Alur Kerja & Menu Operasional',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Menu Grid Layout
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 700 ? 2 : 1,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: MediaQuery.of(context).size.width > 700 ? 1.5 : 1.6,
                  ),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) => menuItems[index],
                ),
                const SizedBox(height: 36),

                // Premium Glassmorphic Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.glassBorder.withOpacity(0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '© 2025 PT. TRI JAYA FAACOS. All Rights Reserved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Built & Maintained by Rafy Pratama (Kepala IT)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withOpacity(0.55),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
      ),
    ),
  ],
),
);
  }
}

