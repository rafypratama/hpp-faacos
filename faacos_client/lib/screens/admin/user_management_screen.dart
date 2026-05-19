import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../widgets/chemical_particle_background.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<UserProvider>(context, listen: false).fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFD97706); // Amber/Gold
      case 'rnd':
        return const Color(0xFF8B5CF6); // Purple/Violet
      case 'kepala_produksi':
        return const Color(0xFF0F766E); // Teal/Emerald
      case 'kepala_gudang':
        return const Color(0xFFEA580C); // Orange/Copper
      default:
        return AppColors.textSecondary;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'rnd':
        return 'R&D Specialist';
      case 'kepala_produksi':
        return 'Kepala Produksi';
      case 'kepala_gudang':
        return 'Kepala Gudang';
      default:
        return role.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    // Filter users based on query
    final filteredUsers = userProvider.users.where((user) {
      final name = user.name.toLowerCase();
      final email = user.email.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Manajemen Pengguna',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryLight),
            onPressed: () => userProvider.fetchUsers(),
          ),
        ],
      ),
      body: Stack(
        children: [
          const ChemicalParticleBackground(),
          Container(
            decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.background.withOpacity(0.95),
              AppColors.surface.withOpacity(0.85),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              const Text(
                'Kelola Karyawan & Hak Akses',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tambahkan akun karyawan baru, edit kredensial, atau kelola otoritas peran mereka.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.surfaceElevated.withOpacity(0.2),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Cari berdasarkan nama atau email...',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),

              // Users List Section
              Expanded(
                child: userProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryLight,
                        ),
                      )
                    : filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 64,
                                  color: AppColors.textSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Tidak ada karyawan yang cocok dengan pencarian.'
                                      : 'Belum ada pengguna terdaftar.',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredUsers.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final isSelf = currentUser?.id == user.id;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.surface,
                                      AppColors.surface.withOpacity(0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelf
                                        ? const Color(0xFFD97706).withOpacity(0.3)
                                        : AppColors.surfaceElevated.withOpacity(0.15),
                                    width: isSelf ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Row(
                                    children: [
                                      // Premium Circular Calligraphy Frame
                                      Container(
                                        height: 52,
                                        width: 52,
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(user.role).withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _getRoleColor(user.role).withOpacity(0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6.0),
                                          child: Image.asset(
                                            'assets/images/logo.png',
                                            fit: BoxFit.contain,
                                            color: _getRoleColor(user.role),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // User Info Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    user.name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isSelf) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFD97706).withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: const Color(0xFFD97706).withOpacity(0.4),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Anda',
                                                      style: TextStyle(
                                                        color: Color(0xFFF59E0B),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              user.email,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 10),

                                            // Premium Role Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getRoleColor(user.role).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: _getRoleColor(user.role).withOpacity(0.2),
                                                ),
                                              ),
                                              child: Text(
                                                _getRoleLabel(user.role),
                                                style: TextStyle(
                                                  color: _getRoleColor(user.role),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Actions Panel
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              color: AppColors.primaryLight,
                                              size: 20,
                                            ),
                                            tooltip: 'Edit Karyawan',
                                            onPressed: () => _showUserDialog(context, user: user),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: isSelf
                                                  ? AppColors.textSecondary.withOpacity(0.3)
                                                  : AppColors.error,
                                              size: 20,
                                            ),
                                            tooltip: isSelf ? 'Tidak bisa menghapus diri sendiri' : 'Hapus Karyawan',
                                            onPressed: isSelf ? null : () => _showDeleteConfirm(context, user),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD97706),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black),
        label: const Text(
          'TAMBAH KARYAWAN',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        onPressed: () => _showUserDialog(context),
      ),
    );
  }

  void _showUserDialog(BuildContext context, {UserModel? user}) {
    final isEdit = user != null;
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    String selectedRole = user?.role ?? 'rnd';

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: AppColors.surfaceElevated.withOpacity(0.3),
                ),
              ),
              title: Text(
                isEdit ? 'Perbarui Karyawan' : 'Tambah Karyawan Baru',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Field
                        const Text(
                          'Nama Karyawan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Masukkan nama lengkap...',
                            prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nama wajib diisi.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email Field
                        const Text(
                          'Email Resmi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'karyawan@faacos.com',
                            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Email wajib diisi.';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                              return 'Format email tidak valid.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (isEdit)
                              const Text(
                                '*Kosongkan jika tidak diganti',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: isEdit ? '••••••••' : 'Masukkan password...',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (val) {
                            if (!isEdit && (val == null || val.isEmpty)) {
                              return 'Password wajib diisi.';
                            }
                            if (val != null && val.isNotEmpty && val.length < 6) {
                              return 'Password minimal 6 karakter.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Role Selection Dropdown
                        const Text(
                          'Peran / Otoritas Role',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.surfaceElevated.withOpacity(0.5),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedRole,
                              dropdownColor: AppColors.surface,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryLight),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setDialogState(() {
                                    selectedRole = newValue;
                                  });
                                }
                              },
                              items: const [
                                DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                                DropdownMenuItem(value: 'rnd', child: Text('R&D Specialist')),
                                DropdownMenuItem(value: 'kepala_produksi', child: Text('Kepala Produksi')),
                                DropdownMenuItem(value: 'kepala_gudang', child: Text('Kepala Gudang')),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.only(bottom: 20, right: 24, left: 24),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'BATAL',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final provider = Provider.of<UserProvider>(context, listen: false);
                      Map<String, dynamic> result;

                      if (isEdit) {
                        result = await provider.updateUser(
                          id: user.id,
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          password: passwordController.text.isNotEmpty ? passwordController.text : null,
                          role: selectedRole,
                        );
                      } else {
                        result = await provider.addUser(
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          password: passwordController.text,
                          role: selectedRole,
                        );
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: result['success'] ? const Color(0xFF0F766E) : AppColors.error,
                            content: Text(
                              result['message'],
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    isEdit ? 'SIMPAN PERUBAHAN' : 'DAFTARKAN AKUN',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: AppColors.error.withOpacity(0.3),
            ),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: 12),
              const Text(
                'Hapus Karyawan?',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: 'Apakah Anda yakin ingin menghapus akun '),
                TextSpan(
                  text: user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const TextSpan(text: ' ('),
                TextSpan(
                  text: user.email,
                  style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.primaryLight),
                ),
                const TextSpan(text: ')? Tindakan ini permanen dan akan mencabut seluruh token sesi aktif pengguna.'),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.all(20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'BATAL',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final provider = Provider.of<UserProvider>(context, listen: false);
                final result = await provider.deleteUser(user.id);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: result['success'] ? const Color(0xFF0F766E) : AppColors.error,
                      content: Text(
                        result['message'],
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'HAPUS PERMANEN',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
