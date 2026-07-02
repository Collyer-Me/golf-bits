import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/brand_app_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/guest_cloud_auth.dart';
import '../auth/profile_bootstrap.dart';
import '../config/supabase_env.dart';
import '../data/course_catalog_repository.dart';
import '../data/friends_repository.dart';
import '../data/history_repository.dart';
import '../data/round_session_store.dart';
import '../data/round_coplayers.dart';
import '../data/schema_compatibility_service.dart';
import '../data/user_preferences_repository.dart';
import '../models/course_catalog_models.dart';
import '../models/friend_models.dart';
import '../models/event_preferences.dart';
import '../models/round_game_config.dart';
import '../models/round_session_args.dart';
import '../models/stroke_tracking.dart';
import '../models/wolf_round_state.dart';
import '../models/wolf_scoring.dart';
import '../theme/app_theme.dart';
import '../widgets/event_preferences_editor.dart';
import '../widgets/guest_cloud_round_sheet.dart';
import '../widgets/outlined_surface_card.dart';
import '../widgets/selectable_surface_card.dart';
import '../widgets/player_avatar.dart';
import '../widgets/setup_step_progress.dart';
import '../widgets/stroke_hole_counter.dart';
import 'hole_scoring_screen.dart';
import 'round_setup_sheets.dart';
import 'wolf_call_screen.dart';

class _Player {
  _Player({
    required this.id,
    required this.name,
    this.email,
    this.userId,
    this.isYou = false,
  });
  final String id;
  final String name;
  final String? email;
  final String? userId;
  final bool isYou;
}

class _Recent {
  _Recent({required this.id, required this.name, required this.rounds});
  final String id;
  final String name;
  final int rounds;
}

/// Five-step new round: format → players → course → handicaps → stakes.
class RoundSetupScreen extends StatefulWidget {
  const RoundSetupScreen({super.key});

  @override
  State<RoundSetupScreen> createState() => _RoundSetupScreenState();
}

class _RoundSetupScreenState extends State<RoundSetupScreen> {
  int _step = 0;
  bool _startingRound = false;
  bool _loadingPlayers = true;

  final List<_Player> _players = <_Player>[];
  final List<_Recent> _recent = <_Recent>[];
  List<FriendConnection> _acceptedFriends = const [];

  final _searchController = TextEditingController();
  String? _selectedCourseId;
  CourseSetupResult? _courseSetup;
  List<CourseSearchHit> _searchHits = [];
  bool _loadingCourseSearch = false;
  int _courseSearchGeneration = 0;
  CourseDetailView? _selectedDetail;
  bool _loadingCourseDetail = false;
  /// False after fetch if [getCourseDetail] returned null for this selection.
  bool _detailFetchSucceeded = false;
  Timer? _searchDebounce;
  /// When false, `hit.id` is not a row in `public.courses` (e.g. offline manual draft).
  bool _roundShouldReferenceCatalog = true;

  static const _totalSteps = 5;

  late List<EventPreference> _events;
  bool _trackHoleScores = false;
  StrokeTrackingMode _strokeScope = StrokeTrackingMode.self;

  final Set<RoundFormat> _formats = {RoundFormat.bits};
  WolfScoringBasis _scoringBasis = WolfScoringBasis.net;
  final Map<String, int> _handicaps = {};
  double _wolfPointValue = 2;
  double _bitsPointValue = 2;

  StrokeTrackingMode get _resolvedStrokeMode {
    if (!_trackHoleScores) return StrokeTrackingMode.off;
    return _strokeScope;
  }

  @override
  void initState() {
    super.initState();
    _events = defaultEventPreferences();
    _searchController.addListener(_onSearchTextChanged);
    unawaited(_loadPlayersFromSupabase());
    unawaited(_loadDefaultEvents());
  }

  void _onSearchTextChanged() {
    if (_step != 2) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_runCourseSearch());
    });
    setState(() {});
  }

  Future<void> _runCourseSearch() async {
    if (!mounted || _step != 2) return;
    final gen = ++_courseSearchGeneration;
    setState(() => _loadingCourseSearch = true);
    final q = _searchController.text.trim();
    final hits = await CourseCatalogRepository.searchCourses(
      query: q,
      includeRemote: q.length >= 2,
    );
    if (!mounted || gen != _courseSearchGeneration) return;
    setState(() {
      _searchHits = hits;
      _loadingCourseSearch = false;
    });
  }

  List<CourseSearchHit> _hitsWithCoverageFromDetail(CourseDetailView d) {
    final idx = _searchHits.indexWhere((h) => h.id == d.id);
    if (idx < 0) return _searchHits;
    final prev = _searchHits[idx];
    if (prev.coverageLevel == d.coverageLevel) return _searchHits;
    final next = prev.copyWith(coverageLevel: d.coverageLevel);
    return [
      ..._searchHits.sublist(0, idx),
      next,
      ..._searchHits.sublist(idx + 1),
    ];
  }

  Future<void> _refreshCourseSearchForStep() async {
    if (_step != 2) return;
    await _runCourseSearch();
  }

  Future<void> _loadCourseDetail(String courseId) async {
    setState(() {
      _loadingCourseDetail = true;
      _selectedDetail = null;
      _detailFetchSucceeded = false;
    });
    final d = await CourseCatalogRepository.getCourseDetail(courseId);
    if (!mounted) return;
    setState(() {
      _loadingCourseDetail = false;
      if (_selectedCourseId == courseId) {
        _selectedDetail = d;
        _detailFetchSucceeded = d != null;
        if (d != null) {
          _searchHits = _hitsWithCoverageFromDetail(d);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultEvents() async {
    try {
      final saved = await UserPreferencesRepository.fetchDefaultEvents();
      if (!mounted) return;
      setState(() => _events = saved);
    } catch (_) {
      // Use built-in defaults if profile settings are unavailable.
    }
  }

  String get _stepLabel => switch (_step) {
        0 => 'PICK YOUR GAMES',
        1 => "WHO'S PLAYING?",
        2 => 'COURSE SELECTION',
        3 => 'SET HANDICAPS',
        _ => 'STAKES & EVENTS',
      };

  bool get _hasWolf => _formats.contains(RoundFormat.wolf);
  bool get _hasBits => _formats.contains(RoundFormat.bits);

  CourseSearchHit? get _selectedCourseHit {
    if (_selectedCourseId == null) return null;
    try {
      return _searchHits.firstWhere((c) => c.id == _selectedCourseId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAddPlayer() async {
    await showAddPlayerSheet(
      context,
      onAdd: (name, email) async {
        String finalName = name;
        String? matchedUserId;
        String? finalEmail = email;
        if (email != null && email.trim().isNotEmpty && SupabaseEnv.isConfigured) {
          try {
            final matched = await HistoryRepository.lookupPlayerByEmail(email);
            if (matched != null) {
              finalName = matched.displayName;
              matchedUserId = matched.userId;
              finalEmail = matched.email;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Matched account: ${matched.displayName}')),
                );
              }
            }
          } catch (_) {
            // Keep local add flow if lookup fails.
          }
        }
        setState(() {
          final id = 'p_${DateTime.now().millisecondsSinceEpoch}';
          _players.add(
            _Player(id: id, name: finalName, email: finalEmail, userId: matchedUserId),
          );
        });
      },
    );
  }

  Future<void> _loadPlayersFromSupabase() async {
    if (!SupabaseEnv.isConfigured) {
      if (!mounted) return;
      setState(() {
        _players
          ..clear()
          ..add(_Player(id: 'you_local', name: 'You', isYou: true));
        _loadingPlayers = false;
      });
      return;
    }
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _players
          ..clear()
          ..add(_Player(id: 'you_local', name: 'You', isYou: true));
        _loadingPlayers = false;
      });
      return;
    }

    String displayName = '';
    try {
      dynamic rows;
      try {
        rows = await client
            .from('profiles')
            .select('display_name')
            .eq('id', user.id)
            .limit(1);
      } catch (_) {
        rows = await client
            .from('profiles')
            .select('display_name')
            .eq('user_id', user.id)
            .limit(1);
      }
      final list = rows as List<dynamic>;
      if (list.isNotEmpty) {
        displayName = ((list.first as Map)['display_name'] as String?)?.trim() ?? '';
      }
    } catch (_) {
      // Non-fatal: fallback below.
    }
    if (displayName.isEmpty) {
      final metaName = (user.userMetadata?['full_name'] as String?)?.trim();
      final emailName = user.email?.split('@').first.trim();
      displayName = (metaName != null && metaName.isNotEmpty)
          ? metaName
          : ((emailName != null && emailName.isNotEmpty) ? emailName : 'You');
    }

    List<FriendConnection> acceptedFriends = const [];
    try {
      final overview = await FriendsRepository.fetchOverview();
      acceptedFriends = overview.where((f) => f.isAccepted).toList()
        ..sort((a, b) => a.otherDisplayName.toLowerCase().compareTo(b.otherDisplayName.toLowerCase()));
    } catch (_) {
      acceptedFriends = const [];
    }

    Map<String, int> counts = const {};
    List<String> recentNames = const [];
    try {
      counts = await RoundCoplayers.fetchCoPlayerCountsForCurrentUser(knownDisplayName: displayName);
      recentNames = await RoundCoplayers.fetchRecentCoPlayerNamesForCurrentUser(
        knownDisplayName: displayName,
        limit: 8,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load recent players from history.')),
        );
      }
    }

    final recents = <MapEntry<String, int>>[
      for (final name in recentNames) MapEntry(name, counts[name] ?? 1),
    ];
    if (recents.length < 8) {
      final used = {for (final r in recents) r.key.trim().toLowerCase()};
      final byCount = counts.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.toLowerCase().compareTo(b.key.toLowerCase());
        });
      for (final entry in byCount) {
        if (recents.length >= 8) break;
        final key = entry.key.trim().toLowerCase();
        if (key.isEmpty || used.contains(key)) continue;
        used.add(key);
        recents.add(entry);
      }
    }

    if (!mounted) return;
    setState(() {
      _players
        ..clear()
        ..add(_Player(id: 'you_${user.id}', name: displayName, email: user.email, userId: user.id, isYou: true));
      _recent
        ..clear()
        ..addAll([
          for (final e in recents.take(8)) _Recent(id: 'recent_${e.key}', name: e.key, rounds: e.value),
        ]);
      _acceptedFriends = acceptedFriends;
      _loadingPlayers = false;
    });
  }

  void _addFromFriend(FriendConnection f) {
    if (_players.any((p) => p.userId == f.otherUserId)) return;
    if (_players.any((p) => p.name.trim().toLowerCase() == f.otherDisplayName.trim().toLowerCase())) return;
    setState(() {
      _players.add(
        _Player(
          id: 'friend_${f.otherUserId}',
          name: f.otherDisplayName,
          email: f.otherEmail,
          userId: f.otherUserId,
        ),
      );
    });
  }

  void _removePlayer(_Player p) {
    if (p.isYou) return;
    setState(() => _players.removeWhere((x) => x.id == p.id));
  }

  void _addFromRecent(_Recent r) {
    if (_players.any((p) => p.name == r.name)) return;
    setState(() {
      _players.add(_Player(id: 'from_${r.id}', name: r.name));
    });
  }

  Future<void> _nextFromCourseStep() async {
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a course first')),
      );
      return;
    }
    final hit = _selectedCourseHit;
    if (hit == null) return;

    if (_loadingCourseDetail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading course…')),
      );
      return;
    }

    final course = _selectedDetail ??
        CourseDetailView(
          id: hit.id,
          name: hit.name,
          subtitle: hit.subtitle,
          coverageLevel: hit.coverageLevel,
          latitude: hit.latitude,
          longitude: hit.longitude,
          address: hit.address,
        );

    final result = await showCourseSetupSheet(
      context,
      courseName: course.name,
      coverageLevel: course.coverageLevel,
      teeOptions: course.tees,
    );
    if (!mounted || result == null) return;
    setState(() {
      _courseSetup = result;
      _step = 3;
    });
    unawaited(_loadHandicapsForPlayers());
  }

  Future<void> _loadHandicapsForPlayers() async {
    final userIds = _players.map((p) => p.userId).toList();
    final fromProfiles = await HistoryRepository.fetchHandicapsForUserIds(userIds);
    String? youName;
    for (final p in _players) {
      if (p.isYou) {
        youName = p.name;
        break;
      }
    }
    final fromHistory = await RoundCoplayers.fetchLastHandicapsForCurrentUser(
      knownDisplayName: youName,
    );
    if (!mounted) return;
    setState(() {
      for (final p in _players) {
        final key = (p.userId != null && p.userId!.isNotEmpty) ? 'u_${p.userId}' : p.id;
        final hc = fromProfiles[p.userId ?? ''] ??
            (p.userId != null && p.userId!.isNotEmpty ? fromHistory.byUserId[p.userId!] : null) ??
            fromHistory.byDisplayNameLower[p.name.trim().toLowerCase()];
        if (hc != null) _handicaps[key] = hc;
      }
    });
  }

  Future<void> _saveCurrentSetupAsDefaults() async {
    try {
      await UserPreferencesRepository.saveDefaultEvents(_events);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved as your default event settings')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save defaults: $e')),
      );
    }
  }

  String _shortCourseTitle(String fullName) {
    return fullName.split(',').first.trim();
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  String _coverageShortLabel(String code) {
    return switch (code) {
      CourseCoverageLevel.manual => 'Manual',
      CourseCoverageLevel.geoOnly => 'Location only',
      CourseCoverageLevel.partialScorecard => 'Partial scorecard',
      CourseCoverageLevel.fullScorecard => 'Full scorecard',
      _ => code.replaceAll('_', ' '),
    };
  }

  String _randomClientUuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = StringBuffer();
    for (final x in b) {
      hex.write(x.toRadixString(16).padLeft(2, '0'));
    }
    final s = hex.toString();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  String _iconKeyForEventName(String name) => iconKeyForEventLabel(name);

  Future<void> _startRound() async {
    if (_startingRound) return;
    if (_formats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one game format')),
      );
      return;
    }
    if (_hasWolf && _players.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wolf requires exactly 4 players')),
      );
      return;
    }
    await RoundSessionStore.clearDraft();
    if (!mounted) return;
    final hit = _selectedCourseHit!;
    final detail = _selectedDetail;
    final setup = _courseSetup!;
    final courseName = hit.name;
    final startHole = setup.holes == 9 ? (setup.frontNineFirst ? 1 : 10) : 1;
    final participants = [
      for (final p in _players)
        RoundParticipant(
          key: (p.userId != null && p.userId!.isNotEmpty) ? 'u_${p.userId}' : p.id,
          displayName: p.name,
          email: p.email,
          userId: p.userId,
          isYou: p.isYou,
          handicap: _handicaps[(p.userId != null && p.userId!.isNotEmpty) ? 'u_${p.userId}' : p.id],
        ),
    ];
    final teeOrder = participants.map((p) => p.key).toList();
    if (_hasWolf) {
      teeOrder.shuffle(Random());
    }
    String? roundId;
    if (SupabaseEnv.isConfigured) {
      setState(() => _startingRound = true);
      try {
        var user = Supabase.instance.client.auth.currentUser;
        var attemptedAnonymousCloud = false;
        if (user == null) {
          final allowGuestCloud = await GuestCloudRoundConsent.ensureAcknowledged(context);
          if (!mounted) {
            return;
          }
          if (allowGuestCloud) {
            attemptedAnonymousCloud = true;
            final guestResult = await GuestCloudAuth.ensureAnonymousSession();
            user = Supabase.instance.client.auth.currentUser;
            if (!guestResult.ok && mounted && guestResult.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(guestResult.errorMessage!)),
              );
            } else if (guestResult.ok) {
              await ProfileBootstrap.ensureCurrentUserProfile();
            }
          }
        }
        if (user == null) {
          if (attemptedAnonymousCloud && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sync unavailable right now. Starting local round on this device.'),
              ),
            );
          }
        } else {
          final compatibility = await SchemaCompatibilityService.checkRoundSyncSchema();
          if (!compatibility.ok) {
            throw StateError(
              'Database schema is not compatible for round sync. '
              'Run pending migrations.\n${compatibility.errors.join('\n')}',
            );
          }
          HistoryRepository.configureRoundColumns(compatibility.detectedColumns['rounds']);
          final holePars = detail?.holeParsForTeeSync(setup.courseTeeId);
          final holeYardages = detail?.holeYardagesForTeeSync(setup.courseTeeId);
          final holeStrokeIndexes = detail?.holeStrokeIndexesForTeeSync(setup.courseTeeId);
          final enabledRules = _events
              .where((e) => e.enabled)
              .map(
                (e) => RoundEventRule(
                  label: e.displayLabel,
                  delta: e.points,
                  iconKey: _iconKeyForEventName(e.displayLabel),
                ),
              )
              .toList();
          final gameConfig = RoundGameConfig(
            formats: _formats.toList(),
            scoringBasis: _scoringBasis,
            teeOrder: teeOrder,
            handicaps: Map<String, int>.from(_handicaps),
            wolfPointValue: _wolfPointValue,
            bitsPointValue: _bitsPointValue,
            eventRules: enabledRules,
          );
          final strokeMode = _hasWolf ? StrokeTrackingMode.all : _resolvedStrokeMode;
          roundId = await HistoryRepository.createInProgressRound(
            courseName: courseName,
            courseShortTitle: _shortCourseTitle(courseName),
            holeCount: setup.holes,
            players: _players.map((p) => p.name).toList(),
            participants: participants,
            currentHole: startHole,
            startHole: startHole,
            courseCatalogId:
                _roundShouldReferenceCatalog && _looksLikeUuid(hit.id) ? hit.id : null,
            courseCoverageLevel: setup.coverageLevel,
            holePars: holePars,
            holeYardages: holeYardages,
            holeStrokeIndexes: holeStrokeIndexes,
            strokeTrackingMode: strokeMode,
            gameConfig: gameConfig,
          );
          await HistoryRepository.sendRoundInvites(
            roundId: roundId,
            courseName: courseName,
            participants: participants,
          );
        }
      } catch (e) {
        // Do not block gameplay; fallback to local round if sync bootstrap fails.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sync unavailable right now. Starting local round on this device.'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _startingRound = false);
      }
    }

    if (setup.coverageLevel == CourseCoverageLevel.manual) {
      unawaited(
        CourseCatalogRepository.logTelemetry('round_start_manual', {
          'courseId': hit.id,
          'holes': setup.holes,
        }),
      );
    } else {
      unawaited(
        CourseCatalogRepository.logTelemetry('round_start', {
          'courseId': hit.id,
          'coverage': setup.coverageLevel,
          'holes': setup.holes,
        }),
      );
    }

    final enabledRules = _events
        .where((e) => e.enabled)
        .map(
          (e) => RoundEventRule(
            label: e.displayLabel,
            delta: e.points,
            iconKey: _iconKeyForEventName(e.displayLabel),
          ),
        )
        .toList();

    final holePars = detail?.holeParsForTeeSync(setup.courseTeeId) ?? const <String, int>{};
    final holeYardages = detail?.holeYardagesForTeeSync(setup.courseTeeId) ?? const <String, int>{};
    final holeStrokeIndexes =
        detail?.holeStrokeIndexesForTeeSync(setup.courseTeeId) ?? const <String, int>{};

    final gameConfig = RoundGameConfig(
      formats: _formats.toList(),
      scoringBasis: _scoringBasis,
      teeOrder: teeOrder,
      handicaps: Map<String, int>.from(_handicaps),
      wolfPointValue: _wolfPointValue,
      bitsPointValue: _bitsPointValue,
      eventRules: enabledRules,
    );

    final strokeMode = _hasWolf ? StrokeTrackingMode.all : _resolvedStrokeMode;

    final args = RoundSessionArgs(
      courseName: courseName,
      courseShortTitle: _shortCourseTitle(courseName),
      holeCount: setup.holes,
      startHole: startHole,
      playerNames: _players.map((p) => p.name).toList(),
      roundId: roundId,
      currentHole: startHole,
      initialScoreByPlayer: {for (final p in participants) p.key: 0},
      eventRules: enabledRules,
      participants: participants,
      strokeTrackingMode: strokeMode,
      holePars: holePars,
      holeYardages: holeYardages,
      holeStrokeIndexes: holeStrokeIndexes,
      gameConfig: gameConfig,
    );
    if (!mounted) return;
    if (_hasWolf) {
      final wolfState = WolfRoundState.fromSession(args);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => WolfCallScreen(state: wolfState)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => HoleScoringScreen(session: args)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BrandAppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step -= 1);
              return;
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Round options',
            onSelected: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Round menu — coming soon')),
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'save', child: Text('Save round')),
              PopupMenuItem(value: 'help', child: Text('Help')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageHorizontal,
              AppTheme.space3,
              AppTheme.pageHorizontal,
              AppTheme.space2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP ${_step + 1} OF $_totalSteps',
                  style: text.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: AppTheme.letterStepCaps,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceHalf),
                SetupStepProgress(
                  currentStep: _step + 1,
                  totalSteps: _totalSteps,
                  labels: const ['FORMAT', 'PLAYERS', 'COURSE', 'HANDICAPS', 'STAKES'],
                ),
                const SizedBox(height: AppTheme.space3),
                Text(
                  _stepLabel,
                  style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: AppTheme.screenPadding.copyWith(top: 0),
              child: switch (_step) {
                0 => _buildFormatStep(context),
                1 => _buildPlayersStep(context),
                2 => _buildCourseStep(context),
                3 => _buildHandicapsStep(context),
                _ => _buildStakesStep(context),
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pageHorizontal,
              AppTheme.space4,
              AppTheme.pageHorizontal,
              MediaQuery.paddingOf(context).bottom + AppTheme.space4,
            ),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step -= 1),
                      child: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: switch (_step) {
                    0 => FilledButton(
                        onPressed: _formats.isEmpty
                            ? null
                            : () => setState(() => _step = 1),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Continue'),
                            SizedBox(width: AppTheme.space2),
                            Icon(Icons.arrow_forward, size: AppTheme.iconArrow),
                          ],
                        ),
                      ),
                    1 => FilledButton(
                        onPressed: _loadingPlayers || _players.isEmpty
                            ? null
                            : () {
                                if (_hasWolf && _players.length != 4) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Wolf needs exactly 4 players')),
                                  );
                                  return;
                                }
                                setState(() => _step = 2);
                                unawaited(_refreshCourseSearchForStep());
                              },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Next'),
                            SizedBox(width: AppTheme.space2),
                            Icon(Icons.arrow_forward, size: AppTheme.iconArrow),
                          ],
                        ),
                      ),
                    2 => FilledButton(
                        onPressed: _nextFromCourseStep,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Next'),
                            SizedBox(width: AppTheme.space2),
                            Icon(Icons.arrow_forward, size: AppTheme.iconArrow),
                          ],
                        ),
                      ),
                    3 => FilledButton(
                        onPressed: () => setState(() => _step = 4),
                        child: const Text('Continue'),
                      ),
                    _ => FilledButton(
                        onPressed: _startingRound ? null : _startRound,
                        child: _startingRound
                            ? SizedBox(
                                height: AppTheme.iconInline,
                                width: AppTheme.iconInline,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              )
                            : const Text('Start round'),
                      ),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    void toggleFormat(RoundFormat format) {
      setState(() {
        if (_formats.contains(format)) {
          if (_formats.length > 1) _formats.remove(format);
        } else {
          _formats.add(format);
        }
      });
    }

    return ListView(
      children: [
        Text(
          'Play just Wolf, or run it alongside bits — pick one or both.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: AppTheme.space3),
        _FormatCard(
          title: 'Bits · Dots · Junk',
          subtitle: 'Free-for-all side game. Award points for birdies, sandies & junk.',
          selected: _hasBits,
          onTap: () => toggleFormat(RoundFormat.bits),
        ),
        SizedBox(height: AppTheme.space2),
        _FormatCard(
          title: 'Wolf',
          subtitle: 'Rotating teams. One Wolf per hole picks a partner — or takes on the group solo.',
          selected: _hasWolf,
          onTap: () => toggleFormat(RoundFormat.wolf),
          showWolfRules: _hasWolf,
        ),
        if (_hasWolf && _hasBits) ...[
          SizedBox(height: AppTheme.space3),
          OutlinedSurfaceCard(
            child: Text(
              'Playing both — Wolf decides the match, bits run alongside as a side game.',
              style: text.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHandicapsStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dimHandicaps = _scoringBasis == WolfScoringBasis.gross;

    return ListView(
      children: [
        Text('SCORING BASIS', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
        SizedBox(height: AppTheme.space2),
        SegmentedButton<WolfScoringBasis>(
          segments: const [
            ButtonSegment(value: WolfScoringBasis.net, label: Text('Net')),
            ButtonSegment(value: WolfScoringBasis.gross, label: Text('Gross')),
          ],
          selected: {_scoringBasis},
          onSelectionChanged: (s) => setState(() => _scoringBasis = s.first),
        ),
        SizedBox(height: AppTheme.space2),
        Text(
          'Strokes apply per hole by stroke index. Switch to Gross to play off scratch.',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: AppTheme.space4),
        Text(
          'PLAYERS · ${_players.length}',
          style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: AppTheme.space2),
        for (var i = 0; i < _players.length; i++) ...[
          _HandicapRow(
            name: _players[i].name,
            colorIndex: i,
            handicap: _handicaps[
                    (_players[i].userId != null && _players[i].userId!.isNotEmpty)
                        ? 'u_${_players[i].userId}'
                        : _players[i].id] ??
                0,
            dimmed: dimHandicaps,
            onChanged: (v) {
              final key = (_players[i].userId != null && _players[i].userId!.isNotEmpty)
                  ? 'u_${_players[i].userId}'
                  : _players[i].id;
              setState(() => _handicaps[key] = v);
            },
          ),
          SizedBox(height: AppTheme.space2),
        ],
      ],
    );
  }

  Widget _buildStakesStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (!_hasBits) {
      return _buildReviewStep(context);
    }

    return ListView(
      children: [
        if (_hasWolf) ...[
          Text('Wolf stake (\$/point)', style: text.titleSmall),
          Slider(
            value: _wolfPointValue,
            min: 1,
            max: 10,
            divisions: 9,
            label: '\$${_wolfPointValue.toStringAsFixed(0)}',
            onChanged: (v) => setState(() => _wolfPointValue = v),
          ),
        ],
        if (_hasBits) ...[
          Text('Bits stake (\$/bit)', style: text.titleSmall),
          Slider(
            value: _bitsPointValue,
            min: 1,
            max: 10,
            divisions: 9,
            label: '\$${_bitsPointValue.toStringAsFixed(0)}',
            onChanged: (v) => setState(() => _bitsPointValue = v),
          ),
        ],
        if (!_hasWolf) ...[
          OutlinedSurfaceCard(
            borderColor: scheme.outlineVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Scorecard', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Track hole scores'),
                  value: _trackHoleScores,
                  onChanged: (v) => setState(() => _trackHoleScores = v),
                ),
                if (_trackHoleScores)
                  SegmentedButton<StrokeTrackingMode>(
                    segments: const [
                      ButtonSegment(value: StrokeTrackingMode.self, label: Text('Just me')),
                      ButtonSegment(value: StrokeTrackingMode.all, label: Text('Everyone')),
                    ],
                    selected: {_strokeScope},
                    onSelectionChanged: (s) => setState(() => _strokeScope = s.first),
                  ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.space3),
        ],
        EventPreferencesEditor(
          events: _events,
          onChanged: (next) => setState(() => _events = next),
          embeddedInScroll: true,
        ),
        SizedBox(height: AppTheme.space3),
        FilledButton.tonalIcon(
          onPressed: _saveCurrentSetupAsDefaults,
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Save as my defaults'),
        ),
        SizedBox(height: AppTheme.space4),
      ],
    );
  }

  Widget _buildPlayersStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (_loadingPlayers) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        Text(
          'Add everyone in your group.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.space4),
        Wrap(
          spacing: AppTheme.space2,
          runSpacing: AppTheme.space2,
          children: [
            ..._players.map((p) {
              return InputChip(
                label: Text(p.name),
                labelStyle: text.labelLarge?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
                onDeleted: p.isYou ? null : () => _removePlayer(p),
                deleteIcon: p.isYou ? null : const Icon(Icons.close, size: AppTheme.iconDense),
                deleteIconColor: scheme.onPrimary,
                selected: true,
                showCheckmark: false,
              );
            }),
            ActionChip(
              avatar: Icon(Icons.add, size: AppTheme.iconDense, color: scheme.primary),
              label: const Text('Add Player'),
              shape: StadiumBorder(
                side: BorderSide(
                  color: scheme.primary.withValues(alpha: AppTheme.opacitySecondaryBorder),
                  width: AppTheme.chipOutlineWidth,
                ),
              ),
              backgroundColor: scheme.surfaceContainerLow,
              onPressed: _openAddPlayer,
            ),
          ],
        ),
        if (_acceptedFriends.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space7),
          Text(
            'Friends',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.space3),
          ..._acceptedFriends.map((f) {
            final already = _players.any((p) => p.userId == f.otherUserId);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space25),
              child: OutlinedSurfaceCard(
                borderColor: scheme.outlineVariant,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.otherDisplayName, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          if (f.otherEmail != null && f.otherEmail!.trim().isNotEmpty)
                            Text(
                              f.otherEmail!.trim(),
                              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      onPressed: already ? null : () => _addFromFriend(f),
                      icon: const Icon(Icons.add),
                      tooltip: already ? 'Already added' : 'Add to round',
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: AppTheme.space7),
        Text(
          'Recent players',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTheme.space3),
        if (_recent.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space4),
            child: Text(
              'No recent players yet. Add people with the button above.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ..._recent.map((r) {
          final already = _players.any((p) => p.name == r.name);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space25),
            child: OutlinedSurfaceCard(
              borderColor: scheme.outlineVariant,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          '${r.rounds} rounds',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: already ? null : () => _addFromRecent(r),
                    icon: const Icon(Icons.add),
                    tooltip: already ? 'Already added' : 'Add',
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCourseStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListView(
      children: [
        SearchBar(
          controller: _searchController,
          hintText: 'Search courses…',
          leading: const Icon(Icons.search),
          onChanged: (_) => setState(() {}),
          trailing: [
            if (_searchController.text.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                  unawaited(_runCourseSearch());
                },
              ),
          ],
        ),
        if (_loadingCourseSearch) ...[
          const SizedBox(height: AppTheme.space3),
          const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.space3),
            child: Text(
              'Searching catalog…',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
        const SizedBox(height: AppTheme.space5),
        if (!_loadingCourseSearch &&
            _searchController.text.trim().isNotEmpty &&
            _searchHits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space5),
            child: Text(
              'No courses matched. Try fewer words, check spelling, or add a course manually.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ..._searchHits.map((c) {
          final selected = _selectedCourseId == c.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space25),
            child: SelectableSurfaceCard(
              selected: selected,
              onTap: () {
                setState(() {
                  _selectedCourseId = c.id;
                  _roundShouldReferenceCatalog = true;
                  _selectedDetail = null;
                });
                unawaited(_loadCourseDetail(c.id));
              },
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space4,
                vertical: AppTheme.buttonPadV,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          c.listSubtitle,
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (selected && _loadingCourseDetail)
                          Padding(
                            padding: const EdgeInsets.only(top: AppTheme.space2),
                            child: Text(
                              'Loading scorecard…',
                              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        if (selected &&
                            !_loadingCourseDetail &&
                            c.coverageLevel == CourseCoverageLevel.geoOnly &&
                            (_selectedDetail?.hasTeeMatrix != true))
                          Padding(
                            padding: const EdgeInsets.only(top: AppTheme.space2),
                            child: Text(
                              'Location only — you can still play; scorecard may be incomplete.',
                              style: text.labelSmall?.copyWith(color: scheme.tertiary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected && _loadingCourseDetail)
                    const SizedBox(
                      width: AppTheme.iconInline,
                      height: AppTheme.iconInline,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (selected)
                    Icon(Icons.check_circle, color: scheme.primary),
                ],
              ),
            ),
          );
        }),
        if (_selectedCourseId != null &&
            _selectedCourseHit != null &&
            !_loadingCourseDetail) ...[
          const SizedBox(height: AppTheme.space4),
          _CourseReadinessCallout(
            summary: CourseReadinessSummary.fromHitAndDetail(
              hit: _selectedCourseHit!,
              detail: _selectedDetail,
              detailFetchSucceeded: _detailFetchSucceeded,
            ),
          ),
        ],
        const SizedBox(height: AppTheme.space2),
        TextButton(
          onPressed: () async {
            final draft = await showManualCourseEntrySheet(context);
            if (!mounted || draft == null) return;
            var persisted = true;
            final created = await CourseCatalogRepository.createManualPrivateCourse(
              name: draft.name,
              subtitle: draft.subtitle,
            );
            late final CourseSearchHit chosen;
            if (created == null) {
              persisted = false;
              chosen = CourseSearchHit(
                id: _randomClientUuid(),
                name: draft.name.trim(),
                subtitle: draft.subtitle?.trim(),
                coverageLevel: CourseCoverageLevel.manual,
              );
            } else {
              chosen = created;
            }
            final detail = CourseDetailView(
              id: chosen.id,
              name: chosen.name,
              subtitle: chosen.subtitle,
              coverageLevel: chosen.coverageLevel,
              address: chosen.address,
            );
            if (!mounted) return;
            setState(() {
              _roundShouldReferenceCatalog = persisted;
              _searchHits = [
                chosen,
                ..._searchHits.where((x) => x.id != chosen.id),
              ];
              _selectedCourseId = chosen.id;
              _selectedDetail = detail;
              _detailFetchSucceeded = true;
            });
          },
          child: Text(
            'Course not listed? Add a course manually…',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final course = _selectedCourseHit;
    final setup = _courseSetup;
    final enabledEvents = _events.where((e) => e.enabled).toList();

    return ListView(
      children: [
        Text(
          'Almost there',
          style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.space4),
        OutlinedSurfaceCard(
          borderColor: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Players', style: text.labelLarge?.copyWith(color: scheme.primary)),
              const SizedBox(height: AppTheme.space2),
              Text(
                _players.map((p) => p.isYou ? '${p.name} (you)' : p.name).join(', '),
                style: text.bodyLarge,
              ),
              const SizedBox(height: AppTheme.space4),
              Text('Course', style: text.labelLarge?.copyWith(color: scheme.primary)),
              const SizedBox(height: AppTheme.space2),
              Text(course?.name ?? '—', style: text.bodyLarge),
              if (setup != null) ...[
                const SizedBox(height: AppTheme.spaceHalf),
                Text(
                  '${setup.holes} holes · ${setup.frontNineFirst ? 'Front' : 'Back'} 9 · ${setup.teeLabel}'
                  '${setup.courseTeeId != null ? '' : ' (generic tees)'} · ${_coverageShortLabel(setup.coverageLevel)}',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppTheme.space4),
              Text('Scorecard', style: text.labelLarge?.copyWith(color: scheme.primary)),
              const SizedBox(height: AppTheme.space2),
              Text(_resolvedStrokeMode.setupLabel, style: text.bodyLarge),
              const SizedBox(height: AppTheme.space4),
              Text('Active events', style: text.labelLarge?.copyWith(color: scheme.primary)),
              const SizedBox(height: AppTheme.space2),
              if (enabledEvents.isEmpty)
                Text('None', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
              else
                ...enabledEvents.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space1),
                    child: Text('• ${e.displayLabel} (${e.points >= 0 ? '+' : ''}${e.points})', style: text.bodyMedium),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseReadinessCallout extends StatelessWidget {
  const _CourseReadinessCallout({required this.summary});

  final CourseReadinessSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (summary.detailUnavailable) {
      return OutlinedSurfaceCard(
        borderColor: scheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.error),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Could not load this course',
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onErrorContainer),
                  ),
                  const SizedBox(height: AppTheme.space1),
                  Text(
                    'Check your connection or try again later. You can pick a different listing or use "Add manually" below.',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final lines = <String>[];
    if (summary.manualOrGeoNote != null) {
      lines.add(summary.manualOrGeoNote!);
    }
    if (summary.expectsScorecardButNoTees) {
      lines.add(
        'Listing indicates a scorecard, but no hole-by-hole tee data loaded. You can still continue — tees will behave like a generic placeholder until better data arrives.',
      );
    }

    if (lines.isEmpty) return const SizedBox.shrink();

    return OutlinedSurfaceCard(
      borderColor: scheme.outlineVariant,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.primary, size: AppTheme.iconNavigation),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines) ...[
                  Text(line, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  if (line != lines.last) const SizedBox(height: AppTheme.space2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.showWolfRules = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool showWolfRules;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SelectableSurfaceCard(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: scheme.primary),
            ],
          ),
          if (showWolfRules) ...[
            Divider(color: scheme.outlineVariant, height: AppTheme.space4),
            Text('+1 Win with partner', style: text.bodySmall),
            Text('×2 Lone Wolf', style: text.bodySmall),
            Text('×3 Blind Wolf', style: text.bodySmall),
            Text('Needs exactly 4 players', style: AppTheme.monoLabel(context)),
          ],
        ],
      ),
    );
  }
}

class _HandicapRow extends StatelessWidget {
  const _HandicapRow({
    required this.name,
    required this.colorIndex,
    required this.handicap,
    required this.onChanged,
    this.dimmed = false,
  });

  final String name;
  final int colorIndex;
  final int handicap;
  final ValueChanged<int> onChanged;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: OutlinedSurfaceCard(
        child: Row(
          children: [
            PlayerAvatar(displayName: name, colorIndex: colorIndex),
            SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('FROM PROFILE', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            StrokeHoleCounter(
              strokes: handicap.clamp(-10, 54),
              min: -10,
              max: 54,
              formatValue: (v) => v < 0 ? '+${-v}' : '$v',
              onChanged: dimmed ? (_) {} : (v) => onChanged(v),
            ),
          ],
        ),
      ),
    );
  }
}
