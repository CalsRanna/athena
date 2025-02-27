class SearchDecision {
  String error = '';
  bool needSearch = false;
  String query = '';

  SearchDecision();

  factory SearchDecision.fromJson(Map<String, dynamic> json) {
    return SearchDecision()
      ..error = json['error']
      ..needSearch = json['need_search']
      ..query = json['query'];
  }
}
