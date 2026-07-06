import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/schedule_event.dart';
import '../../../../repositories/schedule_repository.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/settings_service.dart';
import '../../../../services/cloud_sync_service.dart';

import '../../bloc/schedule_bloc.dart';
import '../../bloc/schedule_event.dart';
import '../../bloc/schedule_state.dart';
import '../widgets/add_edit_event_form.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScheduleBloc(
        repository: context.read<ScheduleRepository>(),
      )..add(ScheduleLoadEvents()),
      child: const ScheduleView(),
    );
  }
}

class ScheduleView extends StatelessWidget {
  const ScheduleView({super.key});

  void _showAddEditEventSheet(BuildContext context, {ScheduleEvent? event}) {
    final bloc = context.read<ScheduleBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditEventForm(
        event: event,
        onSubmit: (newEvent, isReminderOn) async {
          final masterNotifOn = await SettingsService.getNotifWorkout();
          final advanceMinutes = await SettingsService.getWorkoutAdvanceMinutes();
          final repo = context.read<ScheduleRepository>();

          if (event == null) {
            int id = await repo.insertScheduleEvent(newEvent);
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
            await repo.updateScheduleEvent(updatedEvent);
            await NotificationService().cancelEventReminder(event.id!);
            if (isReminderOn && masterNotifOn) {
              await NotificationService().scheduleEventReminder(
                updatedEvent,
                advanceMinutes: advanceMinutes,
              );
            }
            CloudSyncService.syncScheduleToCloud().catchError((_) {});
          }
          bloc.add(ScheduleLoadEvents());
        },
      ),
    );
  }

  void _deleteEvent(BuildContext context, ScheduleEvent event) async {
    final act = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              title: Text('Hapus Jadwal?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: Text('Apakah Anda yakin ingin menghapus jadwal ini?', style: TextStyle(color: AppTheme.textMuted)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Batal', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Hapus', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
              ],
            ));

    if (act == true && event.id != null && context.mounted) {
      context.read<ScheduleBloc>().add(ScheduleDeleteEvent(event.id!));
      await NotificationService().cancelEventReminder(event.id!);
      CloudSyncService.syncScheduleToCloud().catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Agenda ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppTheme.accent, letterSpacing: -1)),
            Text('Hari Ini', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -1)),
          ],
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
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
              _showAddEditEventSheet(context);
            },
            backgroundColor: AppTheme.accent,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            icon: Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Buat Jadwal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          ),
        ),
      ),
      body: BlocBuilder<ScheduleBloc, ScheduleState>(
        builder: (context, state) {
          if (state.isLoading) {
            return Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ScheduleBloc>().add(ScheduleLoadEvents());
            },
            color: AppTheme.accent,
            backgroundColor: AppTheme.surface,
            child: state.allEvents.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
                    children: [
                      Column(
                        children: [
                          Icon(Icons.event_seat_rounded, color: AppTheme.textMuted, size: 80),
                          const SizedBox(height: 24),
                          Text(
                            'Belum ada agenda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Mau buat jadwal baru atau lanjut istirahat?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 14),
                          ),
                        ],
                      )
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                    itemCount: state.allEvents.length,
                    itemBuilder: (context, index) {
                      final event = state.allEvents[index];
                      return InkWell(
                        onTap: () => _showAddEditEventSheet(context, event: event),
                        borderRadius: BorderRadius.circular(26),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: event.type == 'rest' 
                                      ? AppTheme.textPrimary.withValues(alpha: 0.1) 
                                      : AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  event.type == 'rest' ? Icons.bedtime_rounded : Icons.fitness_center_rounded,
                                  color: event.type == 'rest' ? AppTheme.textPrimary : AppTheme.accent,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      event.durationMinutes > 0 ? '${event.durationMinutes} Menit' : 'Waktu Bebas',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Checkbox(
                                value: event.isCompleted,
                                activeColor: AppTheme.accent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (val) {
                                  if (val != null && event.id != null) {
                                    context.read<ScheduleBloc>().add(
                                      ScheduleToggleEventCompletion(event.id!, val)
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed),
                                onPressed: () => _deleteEvent(context, event),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
