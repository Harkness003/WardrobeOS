import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/wardrobe/wardrobe_selection.dart';

void main() {
  test('long-press entry can select the first garment immediately', () {
    final selection = WardrobeSelection();

    selection.select('coat');

    expect(selection.isActive, isTrue);
    expect(selection.value, {'coat'});
    expect(selection.count, 1);
  });

  test('toggle exits selection mode when the last garment is deselected', () {
    final selection = WardrobeSelection()..select('coat');

    selection.toggle('coat');

    expect(selection.isActive, isFalse);
    expect(selection.count, 0);
  });

  test('select all replaces selection and clear cancels it', () {
    final selection = WardrobeSelection()..select('old');

    selection.selectAll(['shirt', 'shoe']);
    expect(selection.value, {'shirt', 'shoe'});

    selection.clear();
    expect(selection.value, isEmpty);
  });
}
