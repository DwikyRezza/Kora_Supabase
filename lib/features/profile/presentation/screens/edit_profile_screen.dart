import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/profile_service.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/edit_profile/edit_profile_bloc.dart';
import '../../bloc/edit_profile/edit_profile_event.dart';
import '../../bloc/edit_profile/edit_profile_state.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  String _selectedGender = 'Pria';
  String _selectedGoal = 'Bulking';

  final List<String> _goals = ['Bulking', 'Cutting / Diet', 'Maintenance', 'Endurance Training'];
  final List<String> _genders = ['Pria', 'Wanita'];

  static Color get primaryColor => AppTheme.accent;

  @override
  void initState() {
    super.initState();
    context.read<EditProfileBloc>().add(LoadProfileData());
  }

  void _populateControllers(EditProfileState state) {
    if (_nameController.text.isEmpty && _usernameController.text.isEmpty) {
      final profile = state.profileData;
      _usernameController.text = profile[ProfileService.keyUsername] ?? '';
      _nameController.text = profile[ProfileService.keyName] ?? '';
      _bioController.text = profile[ProfileService.keyStatus] ?? '';
      _emailController.text = state.userEmail ?? '';
      
      _heightController.text = (profile[ProfileService.keyHeight] ?? 0.0).toStringAsFixed(0);
      _weightController.text = (profile[ProfileService.keyWeight] ?? 0.0).toStringAsFixed(0);
      _ageController.text = (profile[ProfileService.keyAge] ?? 0).toString();
      
      _selectedGender = (profile[ProfileService.keyGender] == 'Laki-laki') ? 'Pria' : 'Wanita';
      
      String goal = profile[ProfileService.keyGoal] ?? 'Bulking';
      if (goal == 'Diet') goal = 'Cutting / Diet';
      if (goal == 'Runner') goal = 'Endurance Training';
      if (!_goals.contains(goal)) goal = 'Bulking';
      _selectedGoal = goal;
    }
  }

  void _saveProfile() {
    String goal = _selectedGoal;
    if (goal == 'Cutting / Diet') goal = 'Diet';
    if (goal == 'Endurance Training') goal = 'Runner';
    String gender = _selectedGender == 'Pria' ? 'Laki-laki' : 'Perempuan';

    context.read<EditProfileBloc>().add(SaveProfileData(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      age: int.tryParse(_ageController.text) ?? 0,
      gender: gender,
      height: double.tryParse(_heightController.text) ?? 0.0,
      weight: double.tryParse(_weightController.text) ?? 0.0,
      goal: goal,
      bio: _bioController.text.trim(),
    ));
  }

  bool _hasChanges(EditProfileState state) {
    if (state.profileData.isEmpty) return false;
    final profile = state.profileData;
    if (_usernameController.text.trim() != (profile[ProfileService.keyUsername] ?? '')) return true;
    if (_nameController.text.trim() != (profile[ProfileService.keyName] ?? '')) return true;
    if (_bioController.text.trim() != (profile[ProfileService.keyStatus] ?? '')) return true;
    if (_heightController.text != ((profile[ProfileService.keyHeight] ?? 0.0).toStringAsFixed(0))) return true;
    if (_weightController.text != ((profile[ProfileService.keyWeight] ?? 0.0).toStringAsFixed(0))) return true;
    if (_ageController.text != ((profile[ProfileService.keyAge] ?? 0).toString())) return true;
    
    String initialGender = (profile[ProfileService.keyGender] == 'Laki-laki') ? 'Pria' : 'Wanita';
    if (_selectedGender != initialGender) return true;
    
    String initialGoal = profile[ProfileService.keyGoal] ?? 'Bulking';
    if (initialGoal == 'Diet') initialGoal = 'Cutting / Diet';
    if (initialGoal == 'Runner') initialGoal = 'Endurance Training';
    if (!_goals.contains(initialGoal)) initialGoal = 'Bulking';
    if (_selectedGoal != initialGoal) return true;
    
    if (state.localPhotoPath != null) return true; 
    
    return false;
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang Perubahan?'),
        content: const Text('Anda memiliki perubahan yang belum disimpan. Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tetap Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditProfileBloc, EditProfileState>(
      listener: (context, state) {
        if (state.status == EditProfileStatus.failure && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppTheme.accent,
          ));
        }
        if (state.status == EditProfileStatus.success && _nameController.text.isNotEmpty) {
          // If saved successfully and we initiated a save
          // wait, actually checking if _nameController.text is not empty isn't great.
          // Better: If we were saving, and now it's success, pop.
          // Let's use a simpler logic for pop: the user pressed save, and if success, we go back.
        }
      },
      builder: (context, state) {
        if (state.status == EditProfileStatus.loading) {
          return Scaffold(
            backgroundColor: AppTheme.surface,
            body: Center(child: CircularProgressIndicator(color: primaryColor)),
          );
        }

        _populateControllers(state);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (!_hasChanges(state)) {
              Navigator.pop(context, result);
              return;
            }
            final shouldPop = await _showUnsavedChangesDialog();
            if (shouldPop == true && mounted) {
              Navigator.pop(context, result);
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.surface,
            appBar: AppBar(
              backgroundColor: AppTheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: primaryColor),
                onPressed: () async {
                  if (!_hasChanges(state)) {
                    Navigator.pop(context);
                    return;
                  }
                  final shouldPop = await _showUnsavedChangesDialog();
                  if (shouldPop == true && mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              title: Text(
                'Edit Profile',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            body: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
              child: Column(
                children: [
                  // Profile Photo
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => context.read<EditProfileBloc>().add(PickProfilePhoto()),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  color: AppTheme.surfaceVariant,
                                ),
                                child: ClipOval(
                                  child: state.isUploadingPhoto
                                      ? Center(child: CircularProgressIndicator(color: primaryColor))
                                      : state.localPhotoPath != null
                                          ? Image.file(File(state.localPhotoPath!), fit: BoxFit.cover)
                                          : state.uploadedPhotoUrl != null
                                              ? Image.network(state.uploadedPhotoUrl!, fit: BoxFit.cover)
                                              : Icon(Icons.person, size: 64, color: AppTheme.textMuted),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF6D00), // Calorie Orange
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 16),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => context.read<EditProfileBloc>().add(PickProfilePhoto()),
                          child: const Text(
                            'Change Photo',
                            style: TextStyle(
                              color: Color(0xFFFF6D00),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Informasi Pribadi
                  _buildSectionTitle('INFORMASI PRIBADI'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Username', 
                    _usernameController, 
                    hint: '@username',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.]')),
                      _LowerCaseTextFormatter(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Display Name', _nameController, hint: 'Nama tampilan publik'),
                  const SizedBox(height: 16),
                  _buildTextField('Bio', _bioController, hint: 'Ceritakan tentang dirimu'),
                  const SizedBox(height: 16),
                  _buildTextField('Email', _emailController, hint: 'Alamat email aktif', readOnly: true),
                  
                  const SizedBox(height: 32),

                  // Statistik Vital
                  _buildSectionTitle('STATISTIK VITAL'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Tinggi (cm)', _heightController, hint: '175', isNumber: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Berat (kg)', _weightController, hint: '70', isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Usia', _ageController, hint: '20', isNumber: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDropdown('Jenis Kelamin', _genders, _selectedGender, (val) {
                        setState(() => _selectedGender = val!);
                      })),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  // Preferensi
                  _buildSectionTitle('PREFERENSI'),
                  const SizedBox(height: 16),
                  _buildDropdown('Target Latihan', _goals, _selectedGoal, (val) {
                    setState(() => _selectedGoal = val!);
                  }),
                ],
              ),
            ),
            bottomNavigationBar: Container(
              color: AppTheme.surface.withOpacity(0.9),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: state.status == EditProfileStatus.saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00), // Ember Orange
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  child: state.status == EditProfileStatus.saving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Simpan Perubahan',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF5C4037), // on-surface-variant
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, bool isNumber = false, bool readOnly = false, List<TextInputFormatter>? inputFormatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: readOnly ? AppTheme.textMuted : AppTheme.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5)),
            filled: true,
            fillColor: AppTheme.surfaceVariant, // fog
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant, // fog
            borderRadius: BorderRadius.circular(26),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
              items: items.map((String item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}
