import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc() : super(const SearchState()) {
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<ClearSearch>(_onClearSearch);
  }

  Future<void> _onSearchQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) async {
    final query = event.query;
    if (query.isEmpty) {
      emit(const SearchState());
      return;
    }

    emit(state.copyWith(status: SearchStatus.loading, query: query));

    try {
      final queryLower = query.toLowerCase();
      final String endQuery = '$queryLower\uf8ff';

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('profile.usernameLower', isGreaterThanOrEqualTo: queryLower)
          .where('profile.usernameLower', isLessThanOrEqualTo: endQuery)
          .limit(20)
          .get();
          
      final results = snap.docs.map((doc) {
        final data = doc.data();
        final profileData = data.containsKey('profile') 
            ? Map<String, dynamic>.from(data['profile'] as Map) 
            : <String, dynamic>{};
        profileData['uid'] = doc.id;
        return profileData;
      }).toList();

      emit(state.copyWith(
        status: SearchStatus.success,
        searchResults: results,
      ));
    } catch (e) {
      print('[SearchBloc] Error searching: $e');
      emit(state.copyWith(
        status: SearchStatus.failure,
        errorMessage: 'Gagal melakukan pencarian',
      ));
    }
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(const SearchState());
  }
}
