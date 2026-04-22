import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../data/course_catalog_repository.dart';
import '../data/history_repository.dart';
import '../data/schema_compatibility_service.dart';
import '../data/user_preferences_repository.dart';
import '../models/course_catalog_models.dart';
import '../models/event_preferences.dart';
import '../models/round_session_args.dart';
import '../theme/app_theme.dart';
import '../widgets/event_preferences_editor.dart';
import '../widgets/outlined_surface_card.dart';
import 'hole_scoring_screen.dart';
import 'round_setup_sheets.dart';

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

/// Four-step new round: players → course (+ setup sheet) → events → review → [HoleScoringScreen].
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

  final _searchController = TextEditingController();
  String? _selectedCourseId;
  CourseSetupResult? _courseSetup;
  List<CourseSearchHit> _searchHits = [];
  bool _loadingCourseSearch = false;
  CourseDetailView? _selectedDetail;
  bool _loadingCourseDetail = false;
  Timer? _searchDebounce;
  /// When false, `hit.id` is not a row in `public.courses` (e.g. offline manual draft).
  bool _roundShouldReferenceCatalog = true;

  late List<EventPreference> _events;

  @override
  void initState() {
    super.initState();
    _events = defaultEventPreferences();
    _searchController.addListener(_onSearchTextChanged);
    unawaited(_loadPlayersFromSupabase());
    unawaited(_loadDefaultEvents());
  }

  void _onSearchTextChanged() {
    if (_step != 1) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_runCourseSearch());
    });
    setState(() {});
  }

  Future<void> _runCourseSearch() async {
    if (!mounted || _step != 1) return;
    setState(() => _loadingCourseSearch = true);
    final q = _searchController.text.trim();
    final hits = await CourseCatalogRepository.searchCourses(
      query: q,
      includeRemote: q.length >= 3,
    );
    if (!mounted) return;
    setState(() {
      _searchHits = hits;
      _loadingCourseSearch = false;
    });
  }

  Future<void> _refreshCourseSearchForStep() async {
    if (_step != 1) return;
    await _runCourseSearch();
  }

  Future<void> _loadCourseDetail(String courseId) async {
    setState(() {
      _loadingCourseDetail = true;
      _selectedDetail = null;
    });
    final d = await CourseCatalogRepository.getCourseDetail(courseId);
    if (!mounted) return;
    setState(() {
      _loadingCourseDetail = false;
      if (_selectedCourseId == courseId) {
        _selectedDetail = d;
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
        0 => "WHO'S PLAYING?",
        1 => 'COURSE SELECTION',
        2 => 'GAME EVENTS',
        _ => 'REVIEW',
      };

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
      setState(() => _loadingPlayers = false);
      return;
    }
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loadingPlayers = false);
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

    final counts = <String, int>{};
    try {
      final rows = await client
          .from('rounds')
          .select('players')
          .eq('created_by', user.id)
          .limit(200);
      for (final row in rows as List<dynamic>) {
        final players = (row as Map)['players'] as List<dynamic>? ?? const [];
        for (final p in players) {
          final name = (p as String).trim();
          if (name.isEmpty) continue;
          if (name.toLowerCase() == displayName.toLowerCase()) continue;
          counts[name] = (counts[name] ?? 0) + 1;
        }
      }
    } catch (_) {
      // Keep Recent players empty if rounds query fails.
    }

    final recents = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    if (!mounted) return;
    setState(() {
      _players
        ..clear()
        ..add(_Player(id: 'you_${user.id}', name: displayName, email: user.email, userId: user.id, isYou: true));
      _recent
        ..clear()
        ..addAll([
          for (final e in recents) _Recent(id: 'recent_${e.key}', name: e.key, rounds: e.value),
        ]);
      _loadingPlayers = false;
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
      _step = 2;
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

  String _iconKeyForEventName(String name) {
    final n = name.toLowerCase();
    if (n.contains('birdie')) return 'sports_golf';
    if (n.contains('eagle')) return 'trending_up';
    if (n.contains('chip')) return 'flag_outlined';
    if (n.contains('putt')) return 'radio_button_checked_outlined';
    if (n.contains('water')) return 'waves_outlined';
    if (n.contains('three') || n.contains('hazard')) return 'remove_circle_outline';
    return 'star_outline';
  }

  Future<void> _goHoleScoring() async {
    if (_startingRound) return;
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
        ),
    ];
    String? roundId;
    if (SupabaseEnv.isConfigured && Supabase.instance.client.auth.currentUser != null) {
      setState(() => _startingRound = true);
      try {
        final compatibility = await SchemaCompatibilityService.checkRoundSyncSchema();
        if (!compatibility.ok) {
          throw StateError(
            'Database schema is not compatible for round sync. '
            'Run pending migrations.\n${compatibility.errors.join('\n')}',
          );
        }
        final holePars = detail?.holeParsForTeeSync(setup.courseTeeId);
        roundId = await HistoryRepository.createInProgressRound(
          courseName: courseName,
          courseShortTitle: _shortCourseTitle(courseName),
          holeCount: setup.holes,
          players: _players.map((p) => p.name).toList(),
          participants: participants,
          currentHole: startHole,
          courseCatalogId:
              _roundShouldReferenceCatalog && _looksLikeUuid(hit.id) ? hit.id : null,
          courseCoverageLevel: setup.coverageLevel,
          holePars: holePars,
        );
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
            label: e.name,
            delta: e.points,
            iconKey: _iconKeyForEventName(e.name),
          ),
        )
        .toList();

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
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => HoleScoringScreen(session: args)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step -= 1);
              return;
            }
            Navigator.of(context).pop();
          },
        ),
        title: const Text('New Round'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Round menu — coming soon')),
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'save', child: Text('Save draft')),
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
                  'STEP ${_step + 1} OF 4',
                  style: text.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: AppTheme.letterStepCaps,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceHalf),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 4,
                    minHeight: AppTheme.radiusSm,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                Text(
                  _stepLabel,
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: AppTheme.screenPadding.copyWith(top: 0),
              child: switch (_step) {
                0 => _buildPlayersStep(context),
                1 => _buildCourseStep(context),
                2 => _buildEventsStep(context),
                _ => _buildReviewStep(context),
              },
            ),
          ),
          Padding(
            padding: AppTheme.screenPadding,
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
                        onPressed: _loadingPlayers || _players.isEmpty
                            ? null
                            : () {
                                setState(() => _step = 1);
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
                    1 => FilledButton(
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
                    2 => FilledButton(
                        onPressed: () => setState(() => _step = 3),
                        child: const Text('Next'),
                      ),
                    _ => FilledButton(
                        onPressed: _startingRound ? null : _goHoleScoring,
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

  Widget _buildPlayersStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (_loadingPlayers) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        Text(
          'Who’s playing?',
          style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppTheme.space4),
        Wrap(
          spacing: AppTheme.space2,
          runSpacing: AppTheme.space2,
          children: [
            ..._players.map((p) {
              return InputChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.name),
                    if (p.isYou) ...[
                      const SizedBox(width: AppTheme.spaceHalf),
                      Text(
                        'YOU',
                        style: text.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                onDeleted: p.isYou ? null : () => _removePlayer(p),
                deleteIcon: p.isYou ? null : const Icon(Icons.close, size: AppTheme.iconDense),
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
        ],
        const SizedBox(height: AppTheme.space5),
        ..._searchHits.map((c) {
          final selected = _selectedCourseId == c.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space25),
            child: Material(
              color: scheme.surface.withValues(alpha: 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                onTap: () {
                  setState(() {
                    _selectedCourseId = c.id;
                    _roundShouldReferenceCatalog = true;
                    _selectedDetail = null;
                  });
                  unawaited(_loadCourseDetail(c.id));
                },
                child: OutlinedSurfaceCard(
                  borderColor: selected ? scheme.primary : scheme.outlineVariant,
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
                            if (selected && c.coverageLevel == CourseCoverageLevel.geoOnly)
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
              ),
            ),
          );
        }),
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

  Widget _buildEventsStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: EventPreferencesEditor(
            events: _events,
            onChanged: (next) => setState(() => _events = next),
          ),
        ),
        SizedBox(height: AppTheme.space3),
        FilledButton.tonalIcon(
          onPressed: _saveCurrentSetupAsDefaults,
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Save as my defaults'),
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
              Text('Active events', style: text.labelLarge?.copyWith(color: scheme.primary)),
              const SizedBox(height: AppTheme.space2),
              if (enabledEvents.isEmpty)
                Text('None', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
              else
                ...enabledEvents.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space1),
                    child: Text('• ${e.name} (${e.points >= 0 ? '+' : ''}${e.points})', style: text.bodyMedium),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
