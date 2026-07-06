import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../models/schedule_event.dart';

class AddEditEventForm extends StatefulWidget {
  final ScheduleEvent? event;
  final Function(ScheduleEvent event, bool isReminderOn) onSubmit;

  const AddEditEventForm({super.key, this.event, required this.onSubmit});

  @override
  State<AddEditEventForm> createState() => _AddEditEventFormState();
}

class _AddEditEventFormState extends State<AddEditEventForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _durationController;
  late TextEditingController _notesController;

  String _type = 'workout';
  String _workoutType = 'running';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isReminderOn = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _durationController = TextEditingController(
        text: widget.event?.durationMinutes.toString() ?? '60');
    _notesController = TextEditingController(text: widget.event?.notes ?? '');

    if (widget.event != null) {
      _type = widget.event!.type;
      _workoutType = widget.event!.workoutType.isEmpty
          ? 'running'
          : widget.event!.workoutType;
      _selectedDate = widget.event!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.dateTime);
      _isReminderOn = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.accent,
            onPrimary: Colors.white,
            surface: AppTheme.surface,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  void _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.accent,
            onPrimary: Colors.white,
            surface: AppTheme.surface,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.event == null ? 'Jadwal Baru' : 'Edit Jadwal',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 24),

                // Kategori
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = 'workout'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _type == 'workout'
                                ? AppTheme.accent.withValues(alpha: 0.1)
                                : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _type == 'workout'
                                    ? AppTheme.accent
                                    : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fitness_center_rounded,
                                  color: _type == 'workout'
                                      ? AppTheme.accent
                                      : AppTheme.textSecondary,
                                  size: 18),
                              const SizedBox(width: 8),
                              Text('Latihan',
                                  style: TextStyle(
                                      color: _type == 'workout'
                                          ? AppTheme.accent
                                          : AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = 'rest'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _type == 'rest'
                                ? AppTheme.textPrimary.withValues(alpha: 0.1)
                                : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _type == 'rest'
                                    ? AppTheme.textPrimary
                                    : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bedtime_rounded,
                                  color: _type == 'rest'
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                  size: 18),
                              const SizedBox(width: 8),
                              Text('Istirahat',
                                  style: TextStyle(
                                      color: _type == 'rest'
                                          ? AppTheme.textPrimary
                                          : AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Judul
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Judul Agenda',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Judul tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),

                // Waktu & Tanggal
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded,
                                  color: AppTheme.accent, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('dd MMM yyyy')
                                    .format(_selectedDate),
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  color: AppTheme.accent, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _selectedTime.format(context),
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Durasi
                if (_type == 'workout')
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Estimasi Durasi (Menit)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                  ),

                if (_type == 'workout') const SizedBox(height: 16),

                // Catatan
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final finalDateTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          _selectedTime.hour,
                          _selectedTime.minute,
                        );

                        final newEvent = ScheduleEvent(
                          id: widget.event?.id,
                          title: _titleController.text,
                          type: _type,
                          dateTime: finalDateTime,
                          workoutType: _type == 'workout' ? _workoutType : '',
                          durationMinutes:
                              int.tryParse(_durationController.text) ?? 60,
                          isCompleted: widget.event?.isCompleted ?? false,
                          notes: _notesController.text,
                        );
                        
                        widget.onSubmit(newEvent, _isReminderOn);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Simpan Jadwal',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
