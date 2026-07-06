import 'package:equatable/equatable.dart';

abstract class EditProfileEvent extends Equatable {
  const EditProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfileData extends EditProfileEvent {}

class PickProfilePhoto extends EditProfileEvent {}

class SaveProfileData extends EditProfileEvent {
  final String name;
  final String username;
  final String bio;
  final double height;
  final double weight;
  final int age;
  final String gender;
  final String goal;

  const SaveProfileData({
    required this.name,
    required this.username,
    required this.bio,
    required this.height,
    required this.weight,
    required this.age,
    required this.gender,
    required this.goal,
  });

  @override
  List<Object?> get props => [name, username, bio, height, weight, age, gender, goal];
}
