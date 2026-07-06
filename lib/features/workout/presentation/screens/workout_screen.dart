import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/workout_main/workout_main_bloc.dart';
import '../../bloc/workout_main/workout_main_event.dart';
import '../widgets/workout_main/workout_activities_tab.dart';
import '../../../analytics/presentation/screens/weekly_report_screen.dart';
import '../../../../utils/responsive.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final WorkoutMainBloc _bloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bloc = WorkoutMainBloc()..add(const WorkoutMainLoadRequested());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: Row(
            children: [
              Text('Aktivitas ',
                  style: TextStyle(
                      fontSize: context.font3XL,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accent,
                      letterSpacing: -1)),
              Text('Latihan',
                  style: TextStyle(
                      fontSize: context.font3XL,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      letterSpacing: -1)),
            ],
          ),
          backgroundColor: AppTheme.surface,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.accent,
                  indicatorWeight: 4,
                  labelColor: AppTheme.textPrimary,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle:
                      TextStyle(fontWeight: FontWeight.w900, fontSize: context.fontMD),
                  tabs: const [
                    Tab(text: 'Progress'),
                    Tab(text: 'Aktivitas'),
                  ],
                ),
                Container(height: 1, color: AppTheme.surfaceVariant),
              ],
            ),
          ),
        ),
        floatingActionButton: null,
        body: TabBarView(
          controller: _tabController,
          children: const [
            WeeklyReportScreen(embedMode: true),
            WorkoutActivitiesTab(),
          ],
        ),
      ),
    );
  }
}
