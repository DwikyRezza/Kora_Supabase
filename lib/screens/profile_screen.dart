import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart'; // import
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSyncing = false; // state loading untuk sinkronisasi
  Map<String, dynamic> _profile = {};
  String? _localPhotoPath;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedGender = 'Laki-laki';
  String _selectedGoal = 'Bulking';

  final List<String> _goals = ['Runner', 'Weightlifter', 'Diet', 'Bulking'];
  final List<String> _genders = ['Laki-laki', 'Perempuan'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ProfileService.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile[ProfileService.keyName] ?? '';
          _ageController.text = (profile[ProfileService.keyAge] ?? 0).toString();
          _heightController.text =
              (profile[ProfileService.keyHeight] ?? 0.0).toString();
          _weightController.text =
              (profile[ProfileService.keyWeight] ?? 0.0).toString();
          _selectedGender =
              profile[ProfileService.keyGender] ?? 'Laki-laki';
          _selectedGoal = profile[ProfileService.keyGoal] ?? 'Bulking';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      // Save to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(appDir.path, fileName);
      await File(pickedFile.path).copy(savedPath);

      setState(() => _localPhotoPath = savedPath);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final age = int.tryParse(_ageController.text) ?? 0;
      final height = double.tryParse(_heightController.text) ?? 0.0;
      final weight = double.tryParse(_weightController.text) ?? 0.0;

      await ProfileService.saveProfile(
        name: name,
        age: age,
        gender: _selectedGender,
        height: height,
        weight: weight,
        goal: _selectedGoal,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil berhasil disimpan! ✅'),
            backgroundColor: AppTheme.neonGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSyncToCloud() async {
    setState(() => _isSyncing = true);
    try {
      await CloudSyncService.backupToCloud();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Semua data berhasil dibackup ke Cloud! ☁️✅'),
            backgroundColor: AppTheme.electricBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal backup: $e'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Keluar dari Akun?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Anda akan keluar dari akun Google. Data profil tetap tersimpan.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child:
                const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: AppTheme.accentRed),
            tooltip: 'Keluar',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                children: [
                  // Profile Photo
                  _buildProfilePhoto(),
                  const SizedBox(height: 8),

                  // Email
                  if (AuthService.isLoggedIn)
                    Text(
                      AuthService.email,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 24),

                  // BMI Card
                  _buildBMICard(),
                  const SizedBox(height: 24),

                  // Form Fields
                  _buildSectionTitle('Informasi Pribadi'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Nama / Username',
                    icon: Icons.person_rounded,
                    type: TextInputType.name,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _ageController,
                          label: 'Usia',
                          icon: Icons.cake_rounded,
                          type: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'Gender',
                          icon: Icons.wc_rounded,
                          value: _selectedGender,
                          items: _genders,
                          onChanged: (v) =>
                              setState(() => _selectedGender = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Data Tubuh'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _heightController,
                          label: 'Tinggi (cm)',
                          icon: Icons.height_rounded,
                          type: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _weightController,
                          label: 'Berat (kg)',
                          icon: Icons.monitor_weight_rounded,
                          type: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Goal Latihan'),
                  const SizedBox(height: 12),
                  _buildGoalSelector(),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sync Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _isSyncing ? null : _handleSyncToCloud,
                      icon: _isSyncing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.electricBlue),
                            )
                          : Icon(Icons.cloud_upload_rounded,
                              color: AppTheme.electricBlue, size: 20),
                      label: Text(
                        _isSyncing ? 'Mencadangkan...' : 'Backup Data ke Cloud',
                        style: TextStyle(
                          color: AppTheme.electricBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppTheme.electricBlue.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(Icons.logout_rounded,
                          color: AppTheme.accentRed, size: 20),
                      label: Text(
                        'Keluar dari Akun',
                        style: TextStyle(
                          color: AppTheme.accentRed,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppTheme.accentRed.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfilePhoto() {
    final photoUrl = _profile['photoUrl'] ?? AuthService.photoUrl;
    final hasLocalPhoto = _localPhotoPath != null;

    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.neonGreenGrad,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonGreen.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: hasLocalPhoto
                  ? Image.file(
                      File(_localPhotoPath!),
                      width: 94,
                      height: 94,
                      fit: BoxFit.cover,
                    )
                  : (photoUrl != null
                      ? Image.network(
                          photoUrl,
                          width: 94,
                          height: 94,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatar(),
                        )
                      : _defaultAvatar()),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.neonGreen,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.background, width: 3),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.black,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    final name = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : (AuthService.displayName.isNotEmpty
            ? AuthService.displayName[0].toUpperCase()
            : 'A');
    return Container(
      width: 94,
      height: 94,
      color: AppTheme.surfaceVariant,
      child: Center(
        child: Text(
          name,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildBMICard() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final height = double.tryParse(_heightController.text) ?? 0;
    if (weight <= 0 || height <= 0) {
      return const SizedBox.shrink();
    }

    final bmi = weight / ((height / 100) * (height / 100));
    final status = ProfileService.getBMIStatus(bmi);
    final statusColor = bmi < 18.5
        ? AppTheme.electricBlue
        : (bmi <= 24.9
            ? AppTheme.neonGreen
            : (bmi <= 29.9 ? AppTheme.accentOrange : AppTheme.accentRed));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.monitor_heart_rounded,
                color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BMI Anda',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${bmi.toStringAsFixed(1)} - $status',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status == 'Ideal' ? '✅' : '⚠️',
            style: const TextStyle(fontSize: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType type,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppTheme.neonGreen, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppTheme.neonGreen, size: 20),
          border: InputBorder.none,
        ),
        dropdownColor: AppTheme.surface,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        items: items
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildGoalSelector() {
    final goalEmoji = {
      'Runner': '🏃',
      'Weightlifter': '🏋️',
      'Diet': '🥗',
      'Bulking': '💪',
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _goals.map((goal) {
        final isSelected = _selectedGoal == goal;
        return GestureDetector(
          onTap: () => setState(() => _selectedGoal = goal),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.neonGreen.withOpacity(0.15)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppTheme.neonGreen
                    : AppTheme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(goalEmoji[goal] ?? '', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  goal,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.neonGreen
                        : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
