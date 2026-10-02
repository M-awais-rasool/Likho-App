import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/likho_api.dart';

/// The month the family's school year starts (April or August), learned the
/// first time a parent moves a child up when Likho asks at the start of a
/// school year. Null until then, and Likho asks in both months. Kept on the
/// phone ([file]).
class SchoolYearMonth extends Notifier<int?> {
  static const file = 'school_year.json';

  @override
  int? build() {
    Future.microtask(_load);
    return null;
  }

  void learn(int month) {
    if (state == month) return;
    state = month;
    unawaited(ref.read(localFilesProvider).write(file, jsonEncode({'month': month})));
  }

  Future<void> _load() async {
    final text = await ref.read(localFilesProvider).read(file);
    if (text == null || !ref.mounted || state != null) return;
    try {
      state = ((jsonDecode(text) as Map)['month'] as num?)?.toInt();
    } catch (e) {
      debugPrint('school year: $e');
    }
  }
}

final schoolYearProvider = NotifierProvider<SchoolYearMonth, int?>(SchoolYearMonth.new);
