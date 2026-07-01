import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/custom_event_draft.dart';
import 'package:golf_bits/models/event_preferences.dart';

void main() {
  group('EventPreference', () {
    test('displayLabel prefers nickname when set', () {
      const event = EventPreference(
        id: 'birdie',
        name: 'Birdie',
        nickname: ' Birdie bonus ',
        description: '',
        defaultPoints: 1,
        enabled: true,
        points: 1,
        isCustom: false,
      );
      expect(event.displayLabel, 'Birdie bonus');
    });

    test('fromJson tolerates missing fields', () {
      final event = EventPreference.fromJson(const {'id': 'x', 'name': 'Custom'});
      expect(event.id, 'x');
      expect(event.enabled, isTrue);
      expect(event.isCustom, isFalse);
    });
  });

  group('defaultEventPreferences', () {
    test('includes standard-set built-ins with junk negatives', () {
      final defaults = defaultEventPreferences();
      expect(
        defaults.map((e) => e.id),
        containsAll([
          'birdie',
          'eagle',
          'greenie',
          'sandie',
          'barkie',
          'chip',
          'prox',
          'long_drive',
          'gir',
          'three',
          'double_plus',
          'water_ob',
        ]),
      );
      expect(defaults.firstWhere((e) => e.id == 'three').points, -1);
      expect(defaults.firstWhere((e) => e.id == 'greenie').description, contains('par 3'));
      expect(defaults.firstWhere((e) => e.id == 'gir').enabled, isFalse);
    });

    test('preset nicknames use regional aliases', () {
      final defaults = defaultEventPreferences();
      expect(defaults.firstWhere((e) => e.id == 'sandie').nickname, 'Sandy');
      expect(defaults.firstWhere((e) => e.id == 'three').nickname, 'Snake');
      expect(defaults.firstWhere((e) => e.id == 'chip').nickname, 'Chippie');
      expect(defaults.firstWhere((e) => e.id == 'barkie').nickname, 'Woodie');
    });
  });

  group('mergeWithDefaultBuiltIns', () {
    test('preserves saved toggles and points for built-ins', () {
      final merged = mergeWithDefaultBuiltIns(const [
        EventPreference(
          id: 'birdie',
          name: 'Birdie',
          nickname: 'Sweet bird',
          description: '',
          defaultPoints: 1,
          enabled: false,
          points: 3,
          isCustom: false,
        ),
      ]);
      final birdie = merged.firstWhere((e) => e.id == 'birdie');
      expect(birdie.enabled, isFalse);
      expect(birdie.points, 3);
      expect(birdie.nickname, 'Sweet bird');
      expect(birdie.name, 'Birdie');
    });

    test('appends custom events after built-ins', () {
      final merged = mergeWithDefaultBuiltIns(const [
        EventPreference(
          id: 'c_1',
          name: 'Longest drive',
          description: 'Off the tee',
          defaultPoints: 1,
          enabled: true,
          points: 1,
          isCustom: true,
        ),
      ]);
      expect(merged.last.isCustom, isTrue);
      expect(merged.last.name, 'Longest drive');
    });
  });

  group('decodeEventPreferencesJson', () {
    test('returns defaults for null or invalid input', () {
      expect(decodeEventPreferencesJson(null), defaultEventPreferences());
      expect(decodeEventPreferencesJson('not-json'), defaultEventPreferences());
      expect(decodeEventPreferencesJson({'bad': true}), defaultEventPreferences());
    });

    test('merges decoded list with built-ins', () {
      final decoded = decodeEventPreferencesJson([
        {'id': 'eagle', 'name': 'Eagle', 'enabled': false, 'points': 5},
      ]);
      final eagle = decoded.firstWhere((e) => e.id == 'eagle');
      expect(eagle.enabled, isFalse);
      expect(eagle.points, 5);
      expect(decoded.any((e) => e.id == 'birdie'), isTrue);
    });
  });

  group('encodeEventPreferencesJson', () {
    test('round-trips through toJson', () {
      final events = defaultEventPreferences();
      final encoded = encodeEventPreferencesJson(events);
      expect(encoded, hasLength(12));
      expect(encoded.first['id'], 'birdie');
    });
  });

  group('iconKeyForEventLabel', () {
    test('maps common nicknames and canonical names', () {
      expect(iconKeyForEventLabel('Snake'), 'radio_button_checked_outlined');
      expect(iconKeyForEventLabel('Sandy'), 'beach_access');
      expect(iconKeyForEventLabel('Nicklaus'), 'straighten');
      expect(iconKeyForEventLabel('Greenie'), 'gps_fixed');
    });
  });

  group('eventPreferenceFromCustomDraft', () {
    test('creates a custom event with generated id', () {
      final event = eventPreferenceFromCustomDraft(
        const CustomEventDraft(name: 'Skins', description: 'Nearest pin', points: 2),
      );
      expect(event.isCustom, isTrue);
      expect(event.id, startsWith('c_'));
      expect(event.points, 2);
    });
  });
}
