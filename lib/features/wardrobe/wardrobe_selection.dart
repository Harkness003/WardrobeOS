import 'package:flutter/foundation.dart';

enum SelectionAction { delete }

/// Selection state kept separately from the wardrobe data and its filters.
class WardrobeSelection extends ValueNotifier<Set<String>> {
  WardrobeSelection() : super(const {});

  bool get isActive => value.isNotEmpty;
  int get count => value.length;
  bool contains(String garmentId) => value.contains(garmentId);

  void select(String garmentId) => _replace({...value, garmentId});

  void toggle(String garmentId) {
    final next = {...value};
    next.contains(garmentId) ? next.remove(garmentId) : next.add(garmentId);
    _replace(next);
  }

  void selectAll(Iterable<String> garmentIds) => _replace(garmentIds.toSet());

  void clear() => _replace(const {});

  void _replace(Set<String> next) {
    if (setEquals(value, next)) return;
    value = Set.unmodifiable(next);
  }
}
