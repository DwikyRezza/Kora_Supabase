import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/schedule_event.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/meal_recommender_service.dart';
import '../services/profile_service.dart';
import '../services/settings_service.dart';
import '../services/cloud_sync_service.dart';
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

  Future<void> _refreshEvents() async {
    try {
      await CloudSyncService.restoreAllFromCloud();
    } catch (_) {} 
    await _loadEvents();
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              title: Text('Hapus Jadwal?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: Text('Apakah Anda yakin ingin menghapus jadwal ini?', style: TextStyle(color: Colors.grey)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Hapus', style: TextStyle(color: Color(0xFFFF3400), fontWeight: FontWeight.bold))),
              ],
            ));

    if (act == true && event.id != null) {
      await _db.deleteScheduleEvent(event.id!);
      await NotificationService().cancelEventReminder(event.id!);
      CloudSyncService.syncScheduleToCloud().catchError((_) {});
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
          final masterNotifOn = await SettingsService.getNotifWorkout();
          final advanceMinutes = await SettingsService.getWorkoutAdvanceMinutes();

          if (event == null) {
            int id = await _db.insertScheduleEvent(newEvent);
            if (isReminderOn && masterNotifOn) {
              final savedEvent = newEvent.copyWith(isCompleted: false);
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
            CloudSyncService.syncScheduleToCloud().catchError((_) {});
          } else {
            final updatedEvent = newEvent.copyWith(isCompleted: event.isCompleted);
            await _db.updateScheduleEvent(updatedEvent);
            await NotificationService().cancelEventReminder(event.id!);
            if (isReminderOn && masterNotifOn) {
              await NotificationService().scheduleEventReminder(
                updatedEvent,
                advanceMinutes: advanceMinutes,
              );
            }
            CloudSyncService.syncScheduleToCloud().catchError((_) {});
          }
          _loadEvents();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Agenda ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF00A9DD), letterSpacing: -1)),
            Text('Hari Ini', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -1)),
          ],
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart, color: AppTheme.textPrimary, size: 28),
            tooltip: 'Laporan Mingguan',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const WeeklyReportScreen(),
              ));
            },
          ),
          SizedBox(width: 16),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            heroTag: 'scheduleFab',
            onPressed: () {
              HapticFeedback.lightImpact();
              _showAddEditEventSheet();
            },
            backgroundColor: const Color(0xFF00A9DD),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            icon: Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Buat Jadwal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF00A9DD)))
          : RefreshIndicator(
              onRefresh: _refreshEvents,
              color: const Color(0xFF00A9DD),
              backgroundColor: AppTheme.surface,
              child: _events.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
                      children: [
                        Column(
                          children: [
                            Icon(Icons.event_seat_rounded, color: Colors.grey, size: 80),
                            SizedBox(height: 24),
                            Text(
                              'Belum ada agenda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Mau buat jadwal baru atau lanjut istirahat?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        )
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return InkWell(
                          onTap: () => _showAddEditEventSheet(event: event),
                          borderRadius: BorderRadius.circular(26),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle),
                                  child: Icon(event.typeIcon, size: 24, color: _getColorForType(event.type)),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(event.title,
                                          style: TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      SizedBox(height: 4),
                                      Text(
                                          '${DateFormat('d MMM yyyy • HH:mm').format(event.dateTime)}',
                                          style: TextStyle(
                                              color: Color(0xFF00A9DD),
                                              fontWeight: FontWeight.bold, fontSize: 12)),
                                      if (event.durationMinutes > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                              'Durasi: ${event.durationMinutes} menit',
                                              style: TextStyle(
                                                  color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: Color(0xFFFF3400)),
                                      onPressed: () => _deleteEvent(event),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.check_circle_outline,
                                          color: Color(0xFF00B33F)),
                                      onPressed: () async {
                                        await _db.updateScheduleEventCompletion(
                                            event.id!, true);
                                        CloudSyncService.syncScheduleToCloud().catchError((_) {});
                                        _loadEvents();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Aktivitas ditandai selesai!')));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'workout': return const Color(0xFF00B33F);
      case 'meal': return const Color(0xFFFF5406);
      case 'rest': return const Color(0xFFBD4BE5);
      default: return const Color(0xFF00A9DD);
    }
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
            primary: const Color(0xFF00A9DD),
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
            primary: const Color(0xFF00A9DD),
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
        notes: _notesController.text.trim(),
      );

      widget.onSubmit(newEvent, _isReminderOn);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _KeyboardPadding(
      child: Container(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
        ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.event == null ? 'Buat Jadwal Baru' : 'Edit Jadwal',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 24),

              TextFormField(
                controller: _titleController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Judul Aktivitas',
                  fillColor: AppTheme.surfaceVariant,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Judul tidak boleh kosong'
                    : null,
              ),
              SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: Colors.white,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  fillColor: AppTheme.surfaceVariant,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none),
                ),
                items: [
                  DropdownMenuItem(value: 'workout', child: Text(' Latihan (Workout)')),
                  DropdownMenuItem(value: 'meal', child: Text(' Nutrisi/Makan')),
                  DropdownMenuItem(value: 'rest', child: Text(' Istirahat')),
                  DropdownMenuItem(value: 'reminder', child: Text(' Pengingat Umum')),
                ],
                onChanged: (val) => setState(() => _type = val!),
              ),
              SizedBox(height: 16),

              if (_type == 'workout') ...[
                DropdownButtonFormField<String>(
                  value: _workoutType,
                  dropdownColor: Colors.white,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Jenis Latihan',
                    fillColor: AppTheme.surfaceVariant,
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide.none),
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

              if (_type == 'meal') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final profile = await ProfileService.getProfile();
                      final goal = profile[ProfileService.keyGoal] ?? 'Bulking';
                      final budget = profile[ProfileService.keyDailyBudget] ?? 50000;
  
                      final rec = MealRecommenderService.getRecommendation(goal, budget);
                      setState(() {
                        _titleController.text = rec.title;
                        _notesController.text =
                            '${rec.description}\n\nEstimasi Harga: Rp${rec.estimatedCost.toInt()} (${rec.category})';
                      });
                    },
                    icon: Icon(Icons.auto_awesome, color: Color(0xFFFF5406)),
                    label: Text('Dapatkan Rekomendasi Menu (AI)', style: TextStyle(color: Color(0xFFFF5406), fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5406).withOpacity(0.1),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Catatan / Menu Spesifik',
                    fillColor: AppTheme.surfaceVariant,
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(26)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today,
                                color: Color(0xFF00A9DD), size: 20),
                            SizedBox(width: 8),
                            Text(DateFormat('d MMM').format(_selectedDate),
                                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(26)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time,
                                color: Color(0xFF00A9DD), size: 20),
                            SizedBox(width: 8),
                            Text(_selectedTime.format(context),
                                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'Estimasi Durasi (Menit)',
                  fillColor: AppTheme.surfaceVariant,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 16),
              
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60, 90].map((minutes) {
                  final label = minutes >= 60
                      ? '${minutes ~/ 60} Jam${minutes % 60 != 0 ? ' ${minutes % 60}m' : ''}'
                      : '${minutes}m';
                  final isSelected =
                      _durationController.text == minutes.toString();
                  return GestureDetector(
                    onTap: () => setState(
                        () => _durationController.text = minutes.toString()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00A9DD)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 24),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Notifikasi Pengingat',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold)),
                subtitle: Text('Alarm akan berbunyi di waktu terjadwal',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                activeColor: const Color(0xFF00A9DD),
                value: _isReminderOn,
                onChanged: (val) => setState(() => _isReminderOn = val),
              ),

              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A9DD),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  child: Text('Simpan Jadwal',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _KeyboardPadding extends StatelessWidget {
  final Widget child;
  const _KeyboardPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: child,
    );
  }
}
