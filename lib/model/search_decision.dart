class SearchDecision {
  final bool needSearch;
  final List<String> keywords;

  SearchDecision({required this.needSearch, required this.keywords});

  factory SearchDecision.fromJson(Map<String, dynamic> json) {
    return SearchDecision(
      needSearch: json['need_search'],
      keywords: List<String>.from(json['keywords']),
    );
  }
}
