import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_event.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'weekly_report_screen.dart';

class ScheduleScreen extends StatefulWidget {
  ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _db = DatabaseHelper();
  List<ScheduleEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await _db.getUpcomingEvents();
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  void _deleteEvent(ScheduleEvent event) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Hapus Jadwal?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Apakah Anda yakin ingin menghapus jadwal ini?', style: TextStyle(color: AppTheme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Hapus', style: TextStyle(color: AppTheme.accentRed))),
        ],
      )
    );

    if (act == true && event.id != null) {
      await _db.deleteScheduleEvent(event.id!);
      await NotificationService().cancelEventReminder(event.id!);
      _loadEvents();
    }
  }

  void _showAddEditEventSheet({ScheduleEvent? event}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditEventForm(
        event: event,
        onSubmit: (newEvent, isReminderOn) async {
          // Cek master switch dari Settings
          final masterNotifOn = await SettingsService.getNotifWorkout();
          final advanceMinutes = await SettingsService.getWorkoutAdvanceMinutes();

          if (event == null) {
            int id = await _db.insertScheduleEvent(newEvent);
            // Gunakan isReminderOn dari form ATAU master switch dari Settings
            if (isReminderOn && masterNotifOn) {
              final savedEvent = newEvent.copyWith(isCompleted: false);
              // Buat event baru dengan id yang baru disimpan
              final eventWithId = ScheduleEvent(
                id: id,
                title: savedEvent.title,
                type: savedEvent.type,
                dateTime: savedEvent.dateTime,
                workoutType: savedEvent.workoutType,
                durationMinutes: savedEvent.durationMinutes,
                notes: savedEvent.notes,
              );
              await NotificationService().scheduleEventReminder(
                eventWithId,
                advanceMinutes: advanceMinutes,
              );
            }
          } else {
            final updatedEvent = newEvent.copyWith(isCompleted: event.isCompleted);
            await _db.updateScheduleEvent(updatedEvent);
            // Selalu batalkan dulu notif lama
            await NotificationService().cancelEventReminder(event.id!);
            // Jadwalkan ulang jika toggle form aktif DAN master switch aktif
            if (isReminderOn && masterNotifOn) {
              await NotificationService().scheduleEventReminder(
                updatedEvent,
                advanceMinutes: advanceMinutes,
              );
            }
          }
          _loadEvents();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(' Jadwal & Pengingat'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart, color: AppTheme.neonGreen),
            tooltip: 'Laporan Mingguan',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => WeeklyReportScreen(),
              ));
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'scheduleFab',
        onPressed: () => _showAddEditEventSheet(),
        backgroundColor: AppTheme.neonGreen,
        foregroundColor: Colors.black,
        icon: Icon(Icons.add_rounded),
        label: Text('Buat Jadwal', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : RefreshIndicator(
              onRefresh: _loadEvents,
              color: AppTheme.neonGreen,
              backgroundColor: AppTheme.surface,
              child: _events.isEmpty
                  ? ListView(
                      padding: EdgeInsets.all(32),
                      children: [
                        Center(
                          child: Text(
                            'Belum ada jadwal.\nTekan tombol di bawah untuk menyusun aktivitasmu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                          ),
                        )
                      ],
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return Card(
                          color: AppTheme.surface,
                          margin: EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showAddEditEventSheet(event: event),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.surfaceVariant,
                                  child: Icon(event.typeIcon, size: 20),
                                ),
                                title: Text(event.title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4),
                                    Text('${DateFormat('d MMM yyyy • HH:mm').format(event.dateTime)}', 
                                        style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.w600)),
                                    if (event.durationMinutes > 0)
                                      Text('Durasi: ${event.durationMinutes} menit', style: TextStyle(color: AppTheme.textMuted)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: AppTheme.accentRed),
                                      onPressed: () => _deleteEvent(event),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.check_circle_outline, color: AppTheme.neonGreen),
                                      onPressed: () async {
                                        await _db.updateScheduleEventCompletion(event.id!, true);
                                        _loadEvents();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktivitas ditandai selesai!')));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _AddEditEventForm extends StatefulWidget {
  final ScheduleEvent? event;
  final Function(ScheduleEvent event, bool isReminderOn) onSubmit;

  const _AddEditEventForm({this.event, required this.onSubmit});

  @override
  State<_AddEditEventForm> createState() => _AddEditEventFormState();
}

class _AddEditEventFormState extends State<_AddEditEventForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _durationController;
  
  String _type = 'workout';
  String _workoutType = 'running';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isReminderOn = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _durationController = TextEditingController(text: widget.event?.durationMinutes.toString() ?? '60');
    
    if (widget.event != null) {
      _type = widget.event!.type;
      _workoutType = widget.event!.workoutType.isEmpty ? 'running' : widget.event!.workoutType;
      _selectedDate = widget.event!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.dateTime);
      // For simplicity, we assume reminder is on if editing. 
      // A more complex app would store reminder boolean in DB.
      _isReminderOn = true; 
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.neonGreen,
            onPrimary: Colors.black,
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
          colorScheme: ColorScheme.dark(
            primary: AppTheme.neonGreen,
            onPrimary: Colors.black,
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

  void _save() {
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
        title: _titleController.text.trim(),
        type: _type,
        dateTime: finalDateTime,
        workoutType: _type == 'workout' ? _workoutType : '',
        durationMinutes: int.tryParse(_durationController.text) ?? 0,
      );

      widget.onSubmit(newEvent, _isReminderOn);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 20),
              Text(widget.event == null ? 'Buat Jadwal Baru' : 'Edit Jadwal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              SizedBox(height: 20),
              
              TextFormField(
                controller: _titleController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Judul Aktivitas',
                  fillColor: AppTheme.surface,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Judul tidak boleh kosong' : null,
              ),
              SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: AppTheme.surface,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  fillColor: AppTheme.surface,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: [
                  DropdownMenuItem(value: 'workout', child: Text(' Workout')),
                  DropdownMenuItem(value: 'meal', child: Text(' Makanan/Nutrisi')),
                  DropdownMenuItem(value: 'rest', child: Text(' Istirahat')),
                  DropdownMenuItem(value: 'reminder', child: Text(' Pengingat Umum')),
                ],
                onChanged: (val) => setState(() => _type = val!),
              ),
              SizedBox(height: 16),

              if (_type == 'workout') ...[
                DropdownButtonFormField<String>(
                  value: _workoutType,
                  dropdownColor: AppTheme.surface,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Jenis Latihan',
                    fillColor: AppTheme.surface,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: [
                    DropdownMenuItem(value: 'running', child: Text('Lari / Running')),
                    DropdownMenuItem(value: 'basketball', child: Text('Basket')),
                    DropdownMenuItem(value: 'weightlifting', child: Text('Angkat Beban')),
                    DropdownMenuItem(value: 'custom', child: Text('Spesifik Lainnya')),
                  ],
                  onChanged: (val) => setState(() => _workoutType = val!),
                ),
                SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppTheme.neonGreen, size: 20),
                            SizedBox(width: 8),
                            Text(DateFormat('d MMM yyyy').format(_selectedDate), style: TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: AppTheme.neonGreen, size: 20),
                            SizedBox(width: 8),
                            Text(_selectedTime.format(context), style: TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _durationController,
                style: TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Estimasi Durasi (Menit)',
                  fillColor: AppTheme.surface,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 16),
              
              SwitchListTile(
                title: Text('Aktifkan Notifikasi Pengingat', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Text('Alarm akan berbunyi di waktu terjadwal', style: TextStyle(color: AppTheme.textMuted)),
                activeColor: AppTheme.neonGreen,
                value: _isReminderOn,
                onChanged: (val) => setState(() => _isReminderOn = val),
              ),

              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Simpan Jadwal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
