import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/body_measurement.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/body_stats/body_stats_bloc.dart';
import '../../bloc/body_stats/body_stats_event.dart';
import '../../bloc/body_stats/body_stats_state.dart';

class BodyStatsScreen extends StatefulWidget {
  const BodyStatsScreen({super.key});

  @override
  State<BodyStatsScreen> createState() => _BodyStatsScreenState();
}

class _BodyStatsScreenState extends State<BodyStatsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BodyStatsBloc>().add(LoadBodyStats());
  }

  Future<void> _refreshData() async {
    context.read<BodyStatsBloc>().add(RefreshBodyStats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Kondisi Tubuh', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      floatingActionButton: BlocBuilder<BodyStatsBloc, BodyStatsState>(
        builder: (context, state) {
          return FloatingActionButton.extended(
            heroTag: 'bodyStatsFab',
            onPressed: () => _showAddMeasurementSheet(context, state.measurements),
            backgroundColor: AppTheme.electricBlue,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Perbarui Data', style: TextStyle(fontWeight: FontWeight.w700)),
          );
        },
      ),
      body: BlocConsumer<BodyStatsBloc, BodyStatsState>(
        listener: (context, state) {
          if (state.status == BodyStatsStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage ?? 'Terjadi kesalahan')),
            );
          }
        },
        builder: (context, state) {
          if (state.status == BodyStatsStatus.loading && state.measurements.isEmpty) {
            return Center(child: CircularProgressIndicator(color: AppTheme.electricBlue));
          }

          final measurements = state.measurements;
          BodyMeasurement? latest = measurements.isNotEmpty ? measurements.first : null;

          return RefreshIndicator(
            onRefresh: _refreshData,
            color: AppTheme.electricBlue,
            backgroundColor: AppTheme.surface,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        _buildWeightChart(measurements),
                        const SizedBox(height: 24),
                        Text('Riwayat Pengukuran', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                if (measurements.isEmpty)
                  SliverFillRemaining(child: Center(child: Text('Belum ada riwayat', style: TextStyle(color: AppTheme.textMuted))))
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final m = measurements[index];
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
                              onPressed: () {
                                if (m.id != null) {
                                  context.read<BodyStatsBloc>().add(DeleteBodyMeasurement(m.id!));
                                }
                              },
                            ),
                          ),
                        );
                      },
                      childCount: measurements.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
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

  Widget _buildWeightChart(List<BodyMeasurement> measurements) {
    if (measurements.length < 2) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
        alignment: Alignment.center,
        child: Text('Butuh minimal 2 data untuk menampilkan grafik', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    // Sort ascending for chart (oldest to newest)
    final sortedData = List<BodyMeasurement>.from(measurements)..sort((a, b) => a.date.compareTo(b.date));
    
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

  void _showAddMeasurementSheet(BuildContext parentContext, List<BodyMeasurement> measurements) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(parentContext).viewInsets.bottom),
        child: _AddMeasurementSheet(
          latestMeasurement: measurements.isNotEmpty ? measurements.first : null,
          onSaved: (weight, height) {
            parentContext.read<BodyStatsBloc>().add(AddBodyMeasurement(weight: weight, height: height));
            Navigator.pop(parentContext);
          }
        ),
      ),
    );
  }
}

class _AddMeasurementSheet extends StatefulWidget {
  final BodyMeasurement? latestMeasurement;
  final Function(double, double) onSaved;
  
  const _AddMeasurementSheet({this.latestMeasurement, required this.onSaved});

  @override
  State<_AddMeasurementSheet> createState() => _AddMeasurementSheetState();
}

class _AddMeasurementSheetState extends State<_AddMeasurementSheet> {
  late TextEditingController _weightCtrl;
  late TextEditingController _heightCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(text: widget.latestMeasurement?.weight.toString() ?? '');
    _heightCtrl = TextEditingController(text: widget.latestMeasurement?.height.toString() ?? '');
  }

  void _save() {
    final weight = double.tryParse(_weightCtrl.text);
    final height = double.tryParse(_heightCtrl.text);

    if (weight == null || height == null) return;
    widget.onSaved(weight, height);
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
