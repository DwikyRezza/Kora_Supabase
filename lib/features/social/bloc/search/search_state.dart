import 'package:equatable/equatable.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<Map<String, dynamic>> searchResults;
  final String? errorMessage;
  final String query;

  const SearchState({
    this.status = SearchStatus.initial,
    this.searchResults = const [],
    this.errorMessage,
    this.query = '',
  });

  SearchState copyWith({
    SearchStatus? status,
    List<Map<String, dynamic>>? searchResults,
    String? errorMessage,
    String? query,
  }) {
    return SearchState(
      status: status ?? this.status,
      searchResults: searchResults ?? this.searchResults,
      errorMessage: errorMessage ?? this.errorMessage,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [status, searchResults, errorMessage, query];
}
