class SearchDecision {
  bool needSearch = false;
  List<String> keywords = [];

  SearchDecision();

  factory SearchDecision.fromJson(Map<String, dynamic> json) {
    return SearchDecision()
      ..needSearch = json['need_search']
      ..keywords = List<String>.from(json['keywords']);
  }
}
