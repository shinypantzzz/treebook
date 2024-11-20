import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:treebook/client.dart';
import 'package:treebook/models.dart';

class Genres extends ChangeNotifier {
  Genres(ApiClient client) {
    update(client);
  }

  final List<Genre> _list = [];

  UnmodifiableListView<Genre> get list => UnmodifiableListView(_list);

  void update(ApiClient client) {
    _list.clear();
    client.fetchGenres().listen(
      (genres) => _list.addAll(genres)
    );
  }
}