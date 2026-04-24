import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'landing_screen.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(Future<bool> Function()?)? onRegisterLeaveGuard;
  const ProfileScreen({super.key, this.onRegisterLeaveGuard});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false; // loading saat upload foto ke Storage
  bool _hasUnsavedChanges = false;
  Map<String, dynamic> _profile = {};
  String? _localPhotoPath;  // path lokal sementara sebelum upload selesai
  String? _uploadedPhotoUrl; // URL Firebase Storage setelah upload

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _budgetController = TextEditingController();
  final _statusController = TextEditingController();
  String _selectedGender = 'Laki-laki';
  String _selectedGoal = 'Bulking';

  final List<String> _goals = ['Runner', 'Weightlifter', 'Diet', 'Bulking'];
  final List<String> _genders = ['Laki-laki', 'Perempuan'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Pantau perubahan pada semua field teks
    _nameController.addListener(_markUnsaved);
    _ageController.addListener(_markUnsaved);
    // Height & weight also trigger BMI card rebuild
    _heightController.addListener(_onBodyDataChanged);
    _weightController.addListener(_onBodyDataChanged);
    _budgetController.addListener(_markUnsaved);
    _statusController.addListener(_markUnsaved);
    // Daftarkan guard pindah tab ke MainNavigation
    widget.onRegisterLeaveGuard?.call(checkUnsavedChanges);
  }

  void _markUnsaved() {
    // Always call setState so BMI card and other computed UI elements re-render
    setState(() => _hasUnsavedChanges = true);
  }

  void _onBodyDataChanged() {
    // Triggers rebuild so BMI card updates in real-time
    setState(() => _hasUnsavedChanges = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _budgetController.dispose();
    _statusController.dispose();
    // Hapus guard saat screen di-dispose
    widget.onRegisterLeaveGuard?.call(null);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ProfileService.getProfile();
      print('[ProfileScreen] getProfile() returned photoUrl: ${profile["photoUrl"]}');

      // Load foto base64 dari Firestore secara paralel
      final photoDataUri = await StorageService.getProfilePhotoDataUri();

      if (mounted) {
        setState(() {
          _profile = profile;
          _nameController.text = profile[ProfileService.keyName] ?? '';
          _ageController.text = (profile[ProfileService.keyAge] ?? 0).toString();
          _heightController.text =
              (profile[ProfileService.keyHeight] ?? 0.0).toString();
          _weightController.text =
              (profile[ProfileService.keyWeight] ?? 0.0).toString();
          _budgetController.text =
              (profile[ProfileService.keyDailyBudget] ?? 50000).toString();
          _statusController.text = profile[ProfileService.keyStatus] ?? '';
          _selectedGender =
              profile[ProfileService.keyGender] ?? 'Laki-laki';
          _selectedGoal = profile[ProfileService.keyGoal] ?? 'Bulking';

          // Prioritas foto yang di-load dari cloud:
          // 1. Data URI dari Firestore (base64) — foto yang di-upload user
          // 2. URL https dari profil (Google atau Firebase Storage)
          if (photoDataUri != null) {
            _uploadedPhotoUrl = photoDataUri; // data:image/jpeg;base64,...
            _localPhotoPath = null;
          } else {
            final savedPhoto = profile['photoUrl'] as String?;
            if (savedPhoto != null && savedPhoto.startsWith('https://')) {
              _uploadedPhotoUrl = savedPhoto;
              _localPhotoPath = null;
            } else {
              _uploadedPhotoUrl = null;
              _localPhotoPath = null;
            }
          }

          _isLoading = false;
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      print('[ProfileScreen] ERROR load: $e');
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
      // Simpan file lokal sementara untuk preview instan
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(appDir.path, fileName);
      await File(pickedFile.path).copy(savedPath);

      setState(() {
        _localPhotoPath = savedPath;   // tampilkan preview dulu
        _uploadedPhotoUrl = null;      // URL belum ada sampai upload selesai
        _isUploadingPhoto = true;
      });

      // Upload ke Firebase Storage
      final url = await StorageService.uploadProfilePhoto(savedPath);

      if (url != null) {
        // ── Upload berhasil (foto tersimpan di Firestore sebagai base64) ──────
        setState(() {
          _uploadedPhotoUrl = url; // data:image/jpeg;base64,... → langsung tampil
          _localPhotoPath = savedPath; // tetap ada untuk preview
          _isUploadingPhoto = false;
        });
        // Simpan profil (foto sudah di Firestore terpisah, tidak perlu pass photoUrl)
        await ProfileService.saveProfile(
          name: _nameController.text.trim(),
          age: int.tryParse(_ageController.text) ?? 0,
          gender: _selectedGender,
          height: double.tryParse(_heightController.text) ?? 0.0,
          weight: double.tryParse(_weightController.text) ?? 0.0,
          goal: _selectedGoal,
          dailyBudget: int.tryParse(_budgetController.text) ?? 50000,
          status: _statusController.text.trim(),
          // photoUrl tidak dikirim — foto sudah tersimpan di Firestore via StorageService
        );
        CloudSyncService.backupToCloud().catchError((_) {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Foto profil berhasil disimpan! ✅'),
              backgroundColor: AppTheme.neonGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        // ── Upload cloud gagal — tetap tampil lokal, JANGAN hapus _localPhotoPath
        setState(() {
          _isUploadingPhoto = false;
          // _localPhotoPath tetap = savedPath → foto tetap tampil di device ini
        });
        // Simpan data profil (tanpa photoUrl lokal — ProfileService akan pakai Google URL)
        await ProfileService.saveProfile(
          name: _nameController.text.trim(),
          age: int.tryParse(_ageController.text) ?? 0,
          gender: _selectedGender,
          height: double.tryParse(_heightController.text) ?? 0.0,
          weight: double.tryParse(_weightController.text) ?? 0.0,
          goal: _selectedGoal,
          dailyBudget: int.tryParse(_budgetController.text) ?? 50000,
          status: _statusController.text.trim(),
          // photoUrl tidak dikirim → ProfileService akan pakai Google URL
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Foto tersimpan sementara. Akan sync ke cloud saat koneksi tersedia.'),
              backgroundColor: AppTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final age = int.tryParse(_ageController.text) ?? 0;
      final height = double.tryParse(_heightController.text) ?? 0.0;
      final weight = double.tryParse(_weightController.text) ?? 0.0;
      final budget = int.tryParse(_budgetController.text) ?? 50000;

      // Hanya kirim cloud URL ke ProfileService.
      // Path lokal TIDAK dikirim — ProfileService akan pakai foto yang sudah ada di cloud.
      final String? photoToSave = _uploadedPhotoUrl; // null jika belum upload ke cloud
      print('[ProfileScreen] Saving profile with photoUrl: $photoToSave');

      await ProfileService.saveProfile(
        name: name,
        age: age,
        gender: _selectedGender,
        height: height,
        weight: weight,
        goal: _selectedGoal,
        dailyBudget: budget,
        status: _statusController.text.trim(),
        photoUrl: photoToSave,
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

        // Simpan _localPhotoPath saat ini sebelum _loadProfile() menghapusnya
        final currentLocalPath = _localPhotoPath;

        await _loadProfile();
        print('[ProfileScreen] Profil di-reload setelah disimpan. photoUrl = ${_profile["photoUrl"]}');

        // Kembalikan _localPhotoPath jika _loadProfile tidak menemukan cloud URL
        // (artinya Firebase Storage belum tersedia, foto lokal tetap ditampilkan)
        if (mounted && _uploadedPhotoUrl == null && currentLocalPath != null) {
          setState(() {
            _localPhotoPath = currentLocalPath;
          });
        }

        // Auto-backup profil ke Firestore
        CloudSyncService.backupToCloud().catchError((_) {});
      }
    } catch (e) {
      print('[ProfileScreen] ERROR simpan: $e');
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
      if (mounted) setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
      });
    }
  }

  /// Periksa apakah ada perubahan belum disimpan, tampilkan dialog jika ada.
  /// Return true = boleh pindah, false = user pilih tetap di sini.
  Future<bool> checkUnsavedChanges() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 24),
            const SizedBox(width: 8),
            Text('Perubahan Belum Disimpan',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Text(
          'Kamu punya perubahan profil yang belum tersimpan.\nApakah ingin disimpan sebelum pindah tab?',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false), // Batal pindah
            child: Text('Kembali & Simpan', style: TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true), // Tetap pindah, buang perubahan
            child: Text('Abaikan', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
    return result ?? false;
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
          MaterialPageRoute(builder: (_) => const LandingScreen()),
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
              padding: EdgeInsets.fromLTRB(context.spaceLG, 8, context.spaceLG, context.space2XL),
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
                  _buildTextField(
                    controller: _statusController,
                    label: 'Status (Semester / Kampus)',
                    icon: Icons.school_rounded,
                    type: TextInputType.text,
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
                          onChanged: (v) => setState(() {
                              _selectedGender = v!;
                              _hasUnsavedChanges = true;
                            }),
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
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Budget Harian'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _budgetController,
                    label: 'Estimasi Budget Makanan (Rp)',
                    icon: Icons.account_balance_wallet_rounded,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: context.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.radiusMD),
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
                          : Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: context.fontMD,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: context.space2XL),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: context.buttonHeight,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(Icons.logout_rounded,
                          color: AppTheme.accentRed, size: context.iconSM),
                      label: Text(
                        'Keluar dari Akun',
                        style: TextStyle(
                          color: AppTheme.accentRed,
                          fontSize: context.fontBase,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppTheme.accentRed.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.radiusMD),
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
    // Prioritas foto:
    // 1. File lokal (_localPhotoPath) — preview instan setelah user pilih foto
    // 2. _uploadedPhotoUrl: bisa berupa:
    //    a. data:image/jpeg;base64,... (foto dari Firestore)
    //    b. https://... (Firebase Storage atau Google)
    // 3. URL Google Sign-In — sama di semua device
    // 4. Default avatar
    final hasLocalPhoto = _localPhotoPath != null && File(_localPhotoPath!).existsSync();
    final hasCloudPhoto = _uploadedPhotoUrl != null;
    final googlePhotoUrl = AuthService.photoUrl;

    Widget photoWidget;
    if (hasLocalPhoto) {
      photoWidget = Image.file(
        File(_localPhotoPath!),
        width: 94, height: 94, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _googleOrDefaultAvatar(googlePhotoUrl),
      );
    } else if (hasCloudPhoto) {
      if (_uploadedPhotoUrl!.startsWith('data:image')) {
        // Base64 data URI — decode dan tampilkan sebagai bytes
        final base64Str = _uploadedPhotoUrl!.split(',').last;
        try {
          final bytes = base64Decode(base64Str);
          photoWidget = Image.memory(
            bytes,
            width: 94, height: 94, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _googleOrDefaultAvatar(googlePhotoUrl),
          );
        } catch (_) {
          photoWidget = _googleOrDefaultAvatar(googlePhotoUrl);
        }
      } else {
        // URL https (Firebase Storage atau Google)
        photoWidget = Image.network(
          _uploadedPhotoUrl!,
          width: 94, height: 94, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _googleOrDefaultAvatar(googlePhotoUrl),
        );
      }
    } else if (googlePhotoUrl != null && googlePhotoUrl.startsWith('http')) {
      photoWidget = Image.network(
        googlePhotoUrl,
        width: 94, height: 94, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultAvatar(),
      );
    } else {
      photoWidget = _defaultAvatar();
    }

    return GestureDetector(
      onTap: _isUploadingPhoto ? null : _pickPhoto,
      child: Stack(
        children: [
          Container(
            width: context.avatarLG,
            height: context.avatarLG,
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
              child: photoWidget,
            ),
          ),
          // Overlay loading saat upload berlangsung
          if (_isUploadingPhoto)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black54,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
          if (!_isUploadingPhoto)
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

  /// Coba tampilkan foto Google, jika gagal fallback ke inisial
  Widget _googleOrDefaultAvatar(String? googleUrl) {
    if (googleUrl != null && googleUrl.startsWith('http')) {
      return Image.network(
        googleUrl,
        width: 94,
        height: 94,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
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
    final goalData = {
      'Runner':      {'emoji': '🏃', 'icon': Icons.directions_run_rounded},
      'Weightlifter':{'emoji': '🏋️', 'icon': Icons.fitness_center_rounded},
      'Diet':        {'emoji': '🥗', 'icon': Icons.eco_rounded},
      'Bulking':     {'emoji': '💪', 'icon': Icons.show_chart_rounded},
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _goals.map((goal) {
        final isSelected = _selectedGoal == goal;
        final data = goalData[goal]!;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedGoal = goal;
            _hasUnsavedChanges = true;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.neonGreen.withOpacity(0.15)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.neonGreen : AppTheme.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.neonGreen.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data['emoji'] as String, style: const TextStyle(fontSize: 18)),
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
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle_rounded,
                      color: AppTheme.neonGreen, size: 14),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
