import re

# Update TrainingVolumeChart signature
with open('lib/widgets/activity/training_volume_chart.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('final double? maxY;', 'final double? maxY;\n  final String unit;')
content = content.replace('this.maxY,', 'this.maxY,\n    this.unit = \"km\",')

# Replace rightTitles
new_right_titles = '''rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  interval: widget.maxY != null ? widget.maxY! / 2 : (maxVolume * 1.2).clamp(1.0, double.infinity) / 2,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max || value == meta.min || value == meta.max / 2) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(' ', 
                            style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
                        );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),'''

content = content.replace('rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),', new_right_titles)

# Remove padding right: 18 since we now have reservedSize: 45 for rightTitles
content = content.replace('padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),', 'padding: const EdgeInsets.only(right: 4, left: 12, top: 24, bottom: 12),')

with open('lib/widgets/activity/training_volume_chart.dart', 'w', encoding='utf-8') as f:
    f.write(content)
