import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../../theme/app_theme.dart';
import '../../../profile/presentation/screens/public_profile_screen.dart';
import '../../../profile/bloc/public_profile/public_profile_bloc.dart';
import '../../bloc/search/search_bloc.dart';
import '../../bloc/search/search_event.dart';
import '../../bloc/search/search_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        if (query.isNotEmpty) {
          context.read<SearchBloc>().add(SearchQueryChanged(query));
        } else {
          context.read<SearchBloc>().add(ClearSearch());
        }
      }
    });
  }

  Widget _buildAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover));
    }
    return Icon(Icons.person, size: 28, color: AppTheme.textMuted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Cari username...',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: AppTheme.textPrimary),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      body: BlocConsumer<SearchBloc, SearchState>(
        listener: (context, state) {
          if (state.status == SearchStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.accentRed,
            ));
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              Divider(color: AppTheme.border, height: 1),
              Expanded(
                child: state.status == SearchStatus.loading
                    ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
                    : state.searchResults.isEmpty && _searchController.text.isNotEmpty && state.status == SearchStatus.success
                        ? Center(
                            child: Text(
                              'Tidak ada hasil untuk "${_searchController.text}"',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : state.searchResults.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
                                    const SizedBox(height: 16),
                                    Text('Cari teman berdasarkan username', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(24),
                                itemCount: state.searchResults.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final user = state.searchResults[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BlocProvider<PublicProfileBloc>(
                                            create: (_) => PublicProfileBloc(),
                                            child: PublicProfileScreen(uid: user['uid']),
                                          ),
                                        ),
                                      );
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppTheme.border, width: 2),
                                            color: AppTheme.surfaceVariant,
                                          ),
                                          child: _buildAvatar(user['photoUrl'] as String?),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user['name'] ?? 'Athlete',
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                user['username'] != null ? '@${user['username']}' : '@athlete',
                                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Color(0xFF5F5E5E)),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          );
        },
      ),
    );
  }
}
