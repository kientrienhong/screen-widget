import 'package:flutter_test/flutter_test.dart';
import 'package:screen_widget/scenes.dart';

void main() {
  test('every scene has a unique id and its own images', () {
    final ids = kScenes.map((s) => s.id).toSet();
    expect(ids.length, kScenes.length);
    for (final s in kScenes) {
      expect(s.background, startsWith('assets/backgrounds/'));
      expect(s.tree, startsWith('assets/trees/'));
      expect(s.sprite, startsWith('assets/sprites/'));
      expect(sceneById(s.id), same(s));
    }
  });
}
