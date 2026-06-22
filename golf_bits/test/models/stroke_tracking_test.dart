import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/models/round_session_args.dart';
import 'package:golf_bits/models/stroke_tracking.dart';

void main() {
  group('StrokeTrackingMode', () {
    test('fromDb maps known values and defaults to off', () {
      expect(StrokeTrackingMode.fromDb('self'), StrokeTrackingMode.self);
      expect(StrokeTrackingMode.fromDb('ALL'), StrokeTrackingMode.all);
      expect(StrokeTrackingMode.fromDb(null), StrokeTrackingMode.off);
      expect(StrokeTrackingMode.fromDb('bogus'), StrokeTrackingMode.off);
    });

    test('toDb round-trips', () {
      expect(StrokeTrackingMode.self.toDb(), 'self');
      expect(StrokeTrackingMode.all.tracksStrokes, isTrue);
      expect(StrokeTrackingMode.off.tracksStrokes, isFalse);
    });
  });

  group('strokeTracksParticipant', () {
    const you = RoundParticipant(key: 'you', displayName: 'You', isYou: true);
    const other = RoundParticipant(key: 'p2', displayName: 'Jamie');

    test('self mode tracks only the local player', () {
      expect(
        strokeTracksParticipant(mode: StrokeTrackingMode.self, participant: you),
        isTrue,
      );
      expect(
        strokeTracksParticipant(mode: StrokeTrackingMode.self, participant: other),
        isFalse,
      );
    });

    test('all mode tracks everyone', () {
      expect(
        strokeTracksParticipant(mode: StrokeTrackingMode.all, participant: other),
        isTrue,
      );
    });
  });

  group('parseStrokeByHole / strokeByHoleToJson', () {
    test('parses nested hole maps and ignores zero or missing strokes', () {
      final parsed = parseStrokeByHole({
        'alex': {'1': 4, '2': 5, '3': 0},
        'empty': {},
        'not-a-map': 1,
      });
      expect(parsed['alex'], {1: 4, 2: 5});
      expect(parsed.containsKey('empty'), isFalse);
      expect(parsed.containsKey('not-a-map'), isFalse);

      final json = strokeByHoleToJson(parsed);
      expect(json, {
        'alex': {'1': 4, '2': 5},
      });
    });
  });

  group('scoreToParLabel', () {
    test('formats even, over, under, and unknown par', () {
      expect(scoreToParLabel(strokes: 4, par: 4), 'E');
      expect(scoreToParLabel(strokes: 5, par: 4), '+1');
      expect(scoreToParLabel(strokes: 3, par: 4), '-1');
      expect(scoreToParLabel(strokes: 38, par: null), '38');
    });
  });

  group('formatGrossWithToPar', () {
    const holePars = {'1': 4, '2': 5, '3': 4};
    const holeOrder = [1, 2, 3];

    test('includes to-par when all played holes have pars', () {
      final label = formatGrossWithToPar(
        gross: 14,
        holePars: holePars,
        holeOrder: holeOrder,
        playerHoles: {1: 4, 2: 5, 3: 5},
      );
      expect(label, '14 (+1)');
    });

    test('uses E when gross matches par sum', () {
      final label = formatGrossWithToPar(
        gross: 13,
        holePars: holePars,
        holeOrder: holeOrder,
        playerHoles: {1: 4, 2: 5, 3: 4},
      );
      expect(label, '13 (E)');
    });

    test('falls back to gross only when pars missing', () {
      final label = formatGrossWithToPar(
        gross: 10,
        holePars: const {'1': 4},
        holeOrder: holeOrder,
        playerHoles: {1: 4, 2: 5},
      );
      expect(label, '10');
    });
  });

  group('computeGrossByPlayer', () {
    test('sums per-hole strokes per participant', () {
      final totals = computeGrossByPlayer({
        'a': {1: 4, 2: 5},
        'b': {1: 3},
      });
      expect(totals, {'a': 9, 'b': 3});
    });
  });

  group('grossLabelForStanding', () {
    test('returns null when stroke tracking is off', () {
      expect(
        grossLabelForStanding(
          mode: StrokeTrackingMode.off,
          grossByPlayer: const {'p1': 40},
          holePars: const {'1': 4},
          holeOrder: const [1],
          strokeByHole: const {'p1': {1: 4}},
          participantKey: 'p1',
        ),
        isNull,
      );
    });

    test('formats score with to-par when hole data exists', () {
      final label = grossLabelForStanding(
        mode: StrokeTrackingMode.all,
        grossByPlayer: const {'p1': 5},
        holePars: const {'1': 4},
        holeOrder: const [1],
        strokeByHole: const {'p1': {1: 5}},
        participantKey: 'p1',
      );
      expect(label, 'Score 5 (+1)');
    });
  });
}
