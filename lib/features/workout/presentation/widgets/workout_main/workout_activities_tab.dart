import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../theme/app_theme.dart';
import '../../../bloc/workout_main/workout_main_bloc.dart';
import '../../../bloc/workout_main/workout_main_event.dart';
import '../../../bloc/workout_main/workout_main_state.dart';
import '../../../../../widgets/feed_post_card.dart';

class WorkoutActivitiesTab extends StatelessWidget {
  const WorkoutActivitiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutMainBloc, WorkoutMainState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Center(child: CircularProgressIndicator(color: AppTheme.accent));
        }

        final filteredPosts = state.userPosts.where((post) {
          final wData = post['workoutData'] as Map<String, dynamic>? ?? {};
          final type = wData['type']?.toString().toLowerCase() ?? 'running';
          return type == state.activeFilter;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            context.read<WorkoutMainBloc>().add(WorkoutMainRefreshRequested());
          },
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _filterChip(context, 'Lari', 'running', state.activeFilter),
                        _filterChip(context, 'Jalan', 'walking', state.activeFilter),
                        _filterChip(context, 'Workout', 'weightlifting', state.activeFilter),
                      ],
                    ),
                  ),
                ),
              ),
              if (filteredPosts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_run_rounded,
                            size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Belum ada aktivitas',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('Mulai berlari atau latihan untuk melihat feed-mu!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == filteredPosts.length - 1 ? 100 : 0),
                        child: FeedPostCard(
                          post: filteredPosts[index],
                          onDataChanged: () {
                            context.read<WorkoutMainBloc>().add(const WorkoutMainLoadRequested(silent: true));
                          },
                        ),
                      );
                    },
                    childCount: filteredPosts.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(BuildContext context, String label, String type, String activeFilter) {
    final isSelected = activeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          context.read<WorkoutMainBloc>().add(WorkoutMainFilterChanged(type));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: isSelected ? AppTheme.accent.withOpacity(0.1) : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ),
      ),
    );
  }
}
