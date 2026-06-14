import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/body_measurement.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';

class BodyStatsScreen extends StatefulWidget {
  const BodyStatsScreen({super.key});

  @override
  State<BodyStatsScreen> createState() => _BodyStatsScreenState();
}

class _BodyStatsScreenState extends State<BodyStatsScreen> {
  final _db = DatabaseHelper();
  List<BodyMeasurement> _measurements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Dipanggil saat pull-to-refresh — sync dari Firestore dulu
  Future<void> _refreshData() async {
    try {
      await CloudSyncService.restoreAllFromCloud();
    } catch (_) {} // silent fail jika offline
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _db.getAllBodyMeasurements();
    
    // If empty, try to seed from profile for the very first time
    if (data.isEmpty) {
      final profile = await ProfileService.getProfile();
      final weight = profile[ProfileService.keyWeight] ?? 0.0;
      final height = profile[ProfileService.keyHeight] ?? 0.0;
      
      if (weight > 0 && height > 0) {
        final initial = BodyMeasurement(
          weight: weight,
          height: height,
          date: DateTime.now().subtract(const Duration(days: 7)), // Fake past week for visual graph
        );
        await _db.insertBodyMeasurement(initial);
        data.add(initial);
      }
    }
    
    if (mounted) {
      setState(() {
        _measurements = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    BodyMeasurement? latest = _measurements.isNotEmpty ? _measurements.first : null;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Kondisi Tubuh', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bodyStatsFab',
        onPressed: _showAddMeasurementSheet,
        backgroundColor: AppTheme.electricBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Perbarui Data', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: AppTheme.electricBlue))
        : RefreshIndicator(
            onRefresh: _refreshData,
            color: AppTheme.electricBlue,
            backgroundColor: AppTheme.surface,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (latest != null) _buildLatestStats(latest),
                        const SizedBox(height: 24),
                        Text('Grafik Berat Badan (kg)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildWeightChart(),
                        const SizedBox(height: 24),
                        Text('Riwayat Pengukuran', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                if (_measurements.isEmpty)
                  SliverFillRemaining(child: Center(child: Text('Belum ada riwayat', style: TextStyle(color: AppTheme.textMuted))))
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final m = _measurements[index];
                        return Card(
                          color: AppTheme.surface,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: AppTheme.surfaceVariant, child: Icon(Icons.monitor_weight_rounded, color: AppTheme.electricBlue)),
                            title: Text('${m.weight} kg', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                            subtitle: Text('BMI: ${m.bmi.toStringAsFixed(1)} • ${DateFormat('dd MMM yy', 'id').format(m.date)}', style: TextStyle(color: AppTheme.textMuted)),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: AppTheme.accentRed),
                              onPressed: () async {
                                await _db.deleteBodyMeasurement(m.id!);
                                _loadData();
                              },
                            ),
                          ),
                        );
                      },
                      childCount: _measurements.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
        ),
    );
  }

  Widget _buildLatestStats(BodyMeasurement latest) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
      child: Column(
        children: [
          Row(
            children: [
              _statItem('Berat', '${latest.weight} kg', AppTheme.electricBlue),
              _statItem('Tinggi', '${latest.height} cm', AppTheme.neonGreen),
              _statItem('BMI', latest.bmi.toStringAsFixed(1), AppTheme.accentOrange),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
            child: Text(
              'Status: ${latest.bmiCategory}',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          )
        ],
      ),
    );
  }

  Widget _statItem(String label, String val, Color c) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(val, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    if (_measurements.length < 2) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
        alignment: Alignment.center,
        child: Text('Butuh minimal 2 data untuk menampilkan grafik', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    // Sort ascending for chart (oldest to newest)
    final sortedData = List<BodyMeasurement>.from(_measurements)..sort((a, b) => a.date.compareTo(b.date));
    
    double minW = sortedData.map((e) => e.weight).reduce((a, b) => a < b ? a : b) - 5;
    double maxW = sortedData.map((e) => e.weight).reduce((a, b) => a > b ? a : b) + 5;

    List<FlSpot> spots = [];
    for (int i = 0; i < sortedData.length; i++) {
        spots.add(FlSpot(i.toDouble(), sortedData[i].weight));
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.border, strokeWidth: 1)),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < sortedData.length) {
                    return Text(DateFormat('dd/MM').format(sortedData[value.toInt()].date), style: TextStyle(color: AppTheme.textSecondary, fontSize: 10));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sortedData.length - 1).toDouble(),
          minY: minW,
          maxY: maxW,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.electricBlue,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.electricBlue.withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMeasurementSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddMeasurementSheet(
          latestMeasurement: _measurements.isNotEmpty ? _measurements.first : null,
          onSaved: () {
            Navigator.pop(context);
            _loadData();
          }
        ),
      ),
    );
  }
}

class _AddMeasurementSheet extends StatefulWidget {
  final BodyMeasurement? latestMeasurement;
  final VoidCallback onSaved;
  const _AddMeasurementSheet({this.latestMeasurement, required this.onSaved});

  @override
  State<_AddMeasurementSheet> createState() => _AddMeasurementSheetState();
}

class _AddMeasurementSheetState extends State<_AddMeasurementSheet> {
  final _db = DatabaseHelper();
  late TextEditingController _weightCtrl;
  late TextEditingController _heightCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(text: widget.latestMeasurement?.weight.toString() ?? '');
    _heightCtrl = TextEditingController(text: widget.latestMeasurement?.height.toString() ?? '');
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weightCtrl.text);
    final height = double.tryParse(_heightCtrl.text);

    if (weight == null || height == null) return;

    final m = BodyMeasurement(
      weight: weight,
      height: height,
      date: DateTime.now(),
    );

    await _db.insertBodyMeasurement(m);
    
    // Read old profile to preserve required arguments
    final prefs = await ProfileService.getProfile();
    final name = prefs[ProfileService.keyName] ?? "Athlete";
    final age = prefs[ProfileService.keyAge] ?? 20;
    final gender = prefs[ProfileService.keyGender] ?? "Pria";
    final goal = prefs[ProfileService.keyGoal] ?? "Bulking";
    // Also update Profile Base target
    await ProfileService.saveProfile(
      name: name,
      username: name.toLowerCase().replaceAll(' ', '_'),
      age: age,
      gender: gender,
      weight: weight, 
      height: height, 
      goal: goal,
      status: prefs['status'] ?? "",
    );widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Update Kondisi Tubuh', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Berat Badan (kg)', prefixIcon: Icon(Icons.monitor_weight_rounded)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Tinggi Badan (cm)', prefixIcon: Icon(Icons.height_rounded)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.electricBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Simpan Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
