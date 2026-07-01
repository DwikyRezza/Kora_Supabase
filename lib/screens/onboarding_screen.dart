import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../screens/landing_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _username = '';
  int _age = 0;
  String _gender = 'Laki-laki';
  double _height = 0.0;
  double _weight = 0.0;
  String _goal = 'Bulking';
  bool _isSaving = false;

  final List<String> _goals = ['Runner', 'Weightlifter', 'Diet', 'Bulking'];
  final List<String> _genders = ['Laki-laki', 'Perempuan'];

  void _saveAndContinue() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() => _isSaving = true);

      // Cek apakah username tersedia
      bool isUsernameAvail = await ProfileService.isUsernameAvailable(_username);
      if (!isUsernameAvail && mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Username "$_username" sudah digunakan. Silakan pilih username lain.'),
            backgroundColor: AppTheme.accent,
          ),
        );
        return;
      }

      // Simpan ke lokal + Firestore
      await ProfileService.saveProfile(
        name: _name.isNotEmpty ? _name : AuthService.displayName,
        username: _username,
        age: _age,
        gender: _gender,
        height: _height,
        weight: _weight,
        goal: _goal,
      );

      // Backup semua data ke Firestore
      CloudSyncService.backupToCloud().catchError((_) {});

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface, // Paper White
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mulai Perjalananmu', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20)),
            Text(AuthService.email ?? '', style: TextStyle(color: const Color(0xFF72A2C5), fontSize: 13, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            await AuthService.signOut();
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LandingScreen()),
              );
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lengkapi Profil Anda',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 32),
              
              _buildTextField('Nama', (v) => _name = v!, TextInputType.name, initialValue: AuthService.displayName),
              SizedBox(height: 20),
              
              // Username Field
              TextFormField(
                style: TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: const Color(0xFF72A2C5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: const Color(0xFFE2E2E2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  prefixIcon: Icon(Icons.alternate_email_rounded, color: const Color(0xFF72A2C5)),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.]')),
                  LowerCaseTextFormatter(),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Username wajib diisi';
                  if (v.length < 3) return 'Minimal 3 karakter';
                  return null;
                },
                onSaved: (v) => _username = v!,
              ),
              SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _buildTextField('Usia', (v) => _age = int.parse(v!), TextInputType.number)),
                  SizedBox(width: 20),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        labelStyle: TextStyle(color: const Color(0xFF72A2C5)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: const Color(0xFFE2E2E2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.accent, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceVariant,
                      ),
                      dropdownColor: AppTheme.surface,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                      initialValue: _gender,
                      items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildTextField('Tinggi Badan (cm)', (v) => _height = double.parse(v!), TextInputType.number)),
                  SizedBox(width: 20),
                  Expanded(child: _buildTextField('Berat Badan (kg)', (v) => _weight = double.parse(v!), TextInputType.number)),
                ],
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Goal Latihan',
                  labelStyle: TextStyle(color: const Color(0xFF72A2C5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: const Color(0xFFE2E2E2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                ),
                dropdownColor: AppTheme.surface,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                initialValue: _goal,
                items: _goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _goal = v!),
              ),
              SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent, // Ember Orange
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)), // Pill radius
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _saveAndContinue,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : const Text(
                          'Simpan & Lanjutkan',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, void Function(String?) onSave, TextInputType type, {String? initialValue}) {
    return TextFormField(
      initialValue: initialValue,
      style: TextStyle(color: AppTheme.textPrimary),
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: const Color(0xFF72A2C5)), // Mist Blue
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: const Color(0xFFE2E2E2)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.accent, width: 2), // Ember Orange
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AppTheme.surfaceVariant, // Fog
      ),
      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
      onSaved: onSave,
    );
  }
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}
