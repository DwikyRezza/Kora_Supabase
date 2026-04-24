import 'package:flutter/material.dart';

class ScheduleEvent {
  final int? id;
  final String title;
  final String type; // 'workout', 'meal', 'rest', 'reminder'
  final DateTime dateTime;
  final String workoutType; // if type == 'workout'
  final int durationMinutes;
  final String notes;
  final bool isCompleted;
  final String status;

  ScheduleEvent({
    this.id,
    required this.title,
    required this.type,
    required this.dateTime,
    this.workoutType = '',
    this.durationMinutes = 60,
    this.notes = '',
    this.isCompleted = false,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'dateTime': dateTime.toIso8601String(),
      'workoutType': workoutType,
      'durationMinutes': durationMinutes,
      'notes': notes,
      'isCompleted': isCompleted ? 1 : 0,
      'status': status,
    };
  }

  factory ScheduleEvent.fromMap(Map<String, dynamic> map) {
    return ScheduleEvent(
      id: map['id'],
      title: map['title'],
      type: map['type'],
      dateTime: DateTime.parse(map['dateTime']),
      workoutType: map['workoutType'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 60,
      notes: map['notes'] ?? '',
      isCompleted: map['isCompleted'] == 1,
      status: map['status'] ?? (map['isCompleted'] == 1 ? 'done' : 'pending'),
    );
  }

  ScheduleEvent copyWith({bool? isCompleted, String? status}) {
    return ScheduleEvent(
      id: id,
      title: title,
      type: type,
      dateTime: dateTime,
      workoutType: workoutType,
      durationMinutes: durationMinutes,
      notes: notes,
      isCompleted: isCompleted ?? this.isCompleted,
      status: status ?? this.status,
    );
  }

  IconData get typeIcon {
    switch (type) {
      case 'workout':
        return Icons.fitness_center;
      case 'meal':
        return Icons.restaurant;
      case 'rest':
        return Icons.bed;
      case 'reminder':
        return Icons.notifications;
      default:
        return Icons.push_pin;
    }
  }
}
