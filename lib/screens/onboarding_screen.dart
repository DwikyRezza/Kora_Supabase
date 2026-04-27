import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _age = 0;
  String _gender = 'Laki-laki';
  double _height = 0.0;
  double _weight = 0.0;
  String _goal = 'Bulking';

  final List<String> _goals = ['Runner', 'Weightlifter', 'Diet', 'Bulking'];
  final List<String> _genders = ['Laki-laki', 'Perempuan'];

  void _saveAndContinue() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      double bmi = _weight / ((_height / 100) * (_height / 100));
      String status = ProfileService.getBMIStatus(bmi);

      // Simpan ke lokal + Firestore (via ProfileService yang sudah diupdate)
      await ProfileService.saveProfile(
        name: _name,
        age: _age,
        gender: _gender,
        height: _height,
        weight: _weight,
        goal: _goal,
      );

      // Backup semua data ke Firestore
      CloudSyncService.backupToCloud().catchError((_) {});

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.neonGreen, size: 28),
                const SizedBox(width: 10),
                Text('Profil Tersimpan!',
                    style: TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.w800)),
              ],
            ),
            content: Text(
              'BMI Anda: ${bmi.toStringAsFixed(1)} — $status\n\nData profil Anda telah disimpan ke cloud. Selamat datang di Kora! 🎉',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainNavigation()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Mulai Sekarang',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mulai Perjalananmu'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.spaceLG),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lengkapi Profil Anda',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: context.font2XL,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.spaceXL),
              _buildTextField('Nama', (v) => _name = v!, TextInputType.name),
              SizedBox(height: context.spaceLG),
              Row(
                children: [
                  Expanded(child: _buildTextField('Usia', (v) => _age = int.parse(v!), TextInputType.number)),
                  SizedBox(width: context.spaceLG),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        labelStyle: TextStyle(color: AppTheme.textMuted),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.neonGreen)),
                      ),
                      dropdownColor: AppTheme.surface,
                      style: TextStyle(color: AppTheme.textPrimary),
                      initialValue: _gender,
                      items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spaceLG),
              Row(
                children: [
                  Expanded(child: _buildTextField('Tinggi Badan (cm)', (v) => _height = double.parse(v!), TextInputType.number)),
                  SizedBox(width: context.spaceLG),
                  Expanded(child: _buildTextField('Berat Badan (kg)', (v) => _weight = double.parse(v!), TextInputType.number)),
                ],
              ),
              SizedBox(height: context.spaceLG),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Goal Latihan',
                  labelStyle: TextStyle(color: AppTheme.textMuted),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.neonGreen)),
                ),
                dropdownColor: AppTheme.surface,
                style: TextStyle(color: AppTheme.textPrimary),
                initialValue: _goal,
                items: _goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _goal = v!),
              ),
              SizedBox(height: context.space2XL),
              SizedBox(
                width: double.infinity,
                height: context.buttonHeight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.radiusMD)),
                  ),
                  onPressed: _saveAndContinue,
                  child: Text(
                    'Simpan & Lanjutkan',
                    style: TextStyle(color: Colors.black, fontSize: context.fontMD, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, void Function(String?) onSave, TextInputType type) {
    return TextFormField(
      style: TextStyle(color: AppTheme.textPrimary),
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textMuted),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.neonGreen)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
      onSaved: onSave,
    );
  }
}
