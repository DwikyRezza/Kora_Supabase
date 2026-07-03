import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TrainingVolumeChart extends StatefulWidget {
  final List<double> weeklyVolumes; // Data untuk 12 minggu (3 bulan x 4 minggu)

  const TrainingVolumeChart({
    super.key,
    required this.weeklyVolumes,
  }) : assert(weeklyVolumes.length == 12, 'Must provide exactly 12 weekly data points (4 weeks x 3 months)');

  @override
  State<TrainingVolumeChart> createState() => _TrainingVolumeChartState();
}

class _TrainingVolumeChartState extends State<TrainingVolumeChart> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    // Cari nilai maksimum agar maxY di chart proporsional
    final maxVolume = widget.weeklyVolumes.isEmpty 
        ? 0.0 
        : widget.weeklyVolumes.reduce((curr, next) => curr > next ? curr : next);

    return AspectRatio(
      aspectRatio: 1.70,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            // KUNCI: Konfigurasi Touch/Drag (Continuous tracking ala Strava)
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true, // Otomatis menangani drag dan snap
              getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    const FlLine(
                      color: Colors.grey, // Garis vertikal indikator yang mengikuti jari
                      strokeWidth: 2,
                    ),
                    FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 6,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: Colors.blueAccent,
                      ),
                    ),
                  );
                }).toList();
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => Colors.black87, // Tooltip Background
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((LineBarSpot touchedSpot) {
                    return LineTooltipItem(
                      touchedSpot.y.toStringAsFixed(1),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
              touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                // Tracking index secara realtime saat continuous drag / tap
                if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                  setState(() {
                    touchedIndex = response.lineBarSpots![0].spotIndex;
                  });
                }
                
                // Menghilangkan indikator jika sentuhan diangkat (lift off)
                if (event is FlTapUpEvent || event is FlPanEndEvent || event is FlLongPressEnd) {
                  setState(() {
                    touchedIndex = null;
                  });
                }
              },
            ),
            gridData: const FlGridData(show: false), // Strava tidak menampilkan grid utama di tengah
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Sembunyikan y-axis labels agar clean
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 4, // 1 label per bulan (4 minggu)
                  getTitlesWidget: (value, meta) {
                    const style = TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 12,
                      color: Colors.grey,
                    );
                    
                    String text;
                    // value berjalan dari 0 sampai 11
                    if (value == 0) {
                      text = 'Bulan 1';
                    } else if (value == 4) {
                      text = 'Bulan 2';
                    } else if (value == 8) {
                      text = 'Bulan 3';
                    } else {
                      return const SizedBox.shrink();
                    }
                    
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 8.0,
                      child: Text(text, style: style),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.5), width: 1.5),
              ),
            ),
            minX: 0,
            maxX: 11,
            minY: 0,
            maxY: (maxVolume * 1.2).clamp(1.0, double.infinity), // Buffer ruang 20% di atas agar titik max tidak tertutup tooltip
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  12,
                  (index) => FlSpot(index.toDouble(), widget.weeklyVolumes[index]),
                ),
                isCurved: false, // Grafik volume Strava umumnya tegak lurus ke titik minggu
                color: Colors.deepOrange, // Menggunakan warna orange ala Strava
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true, // Tampilkan titik untuk SEMUA minggu
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 3.5,
                    color: Colors.white, // Titik tengah putih
                    strokeWidth: 2,
                    strokeColor: Colors.deepOrange, // Pinggiran orange
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrange.withOpacity(0.4),
                      Colors.deepOrange.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
