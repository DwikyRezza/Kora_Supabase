import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // To navigate to MainNavigation

class OnboardingScreen extends StatefulWidget {
  OnboardingScreen({super.key});

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

      await ProfileService.saveProfile(
        name: _name,
        age: _age,
        gender: _gender,
        height: _height,
        weight: _weight,
        goal: _goal,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text('Profil Tersimpan', style: TextStyle(color: AppTheme.neonGreen)),
            content: Text(
              'BMI Anda: ${bmi.toStringAsFixed(1)}\nStatus: $status\n\nTarget Protein telah disesuaikan dengan goal Anda.',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => MainNavigation()),
                  );
                },
                child: Text('Mulai', style: TextStyle(color: AppTheme.neonGreen)),
              )
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
        title: Text('Mulai Perjalananmu'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lengkapi Profil Anda',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              _buildTextField('Nama', (v) => _name = v!, TextInputType.name),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField('Usia', (v) => _age = int.parse(v!), TextInputType.number)),
                  SizedBox(width: 16),
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
                      value: _gender,
                      items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField('Tinggi Badan (cm)', (v) => _height = double.parse(v!), TextInputType.number)),
                  SizedBox(width: 16),
                  Expanded(child: _buildTextField('Berat Badan (kg)', (v) => _weight = double.parse(v!), TextInputType.number)),
                ],
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Goal Latihan',
                  labelStyle: TextStyle(color: AppTheme.textMuted),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.neonGreen)),
                ),
                dropdownColor: AppTheme.surface,
                style: TextStyle(color: AppTheme.textPrimary),
                value: _goal,
                items: _goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _goal = v!),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveAndContinue,
                  child: Text(
                    'Simpan & Lanjutkan',
                    style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
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
