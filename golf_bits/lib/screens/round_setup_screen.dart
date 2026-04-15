import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import '../models/round_session_args.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'hole_scoring_screen.dart';
import 'round_setup_sheets.dart';

class _Player {
  _Player({required this.id, required this.name, this.isYou = false});
  final String id;
  final String name;
  final bool isYou;
}

class _Recent {
  _Recent({required this.id, required this.name, required this.rounds});
  final String id;
  final String name;
  final int rounds;
}

class _Course {
  const _Course({required this.id, required this.name, required this.subtitle});
  final String id;
  final String name;
  final String subtitle;
}

class _EventRow {
  _EventRow({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultPoints,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String description;
  final int defaultPoints;
  final bool isCustom;
  bool enabled = true;
  int points = 0;

  void resetPoints() => points = defaultPoints;
}

/// Four-step new round: players → course (+ setup sheet) → events → review → [HoleScoringScreen].
class RoundSetupScreen extends StatefulWidget {
  const RoundSetupScreen({super.key});

  @override
  State<RoundSetupScreen> createState() => _RoundSetupScreenState();
}

class _RoundSetupScreenState extends State<RoundSetupScreen> with SingleTickerProviderStateMixin {
  int _step = 0;
  bool _startingRound = false;
  bool _loadingPlayers = true;

  final List<_Player> _players = <_Player>[];
  final List<_Recent> _recent = <_Recent>[];

  final _searchController = TextEditingController();
  String? _selectedCourseId;
  CourseSetupResult? _courseSetup;

  late final TabController _eventTabController;
  late List<_EventRow> _events;

  static const _courses = [
    _Course(id: 'rm', name: 'Royal Melbourne Golf Club', subtitle: 'Black Rock, VIC'),
    _Course(id: 'rs', name: 'Royal Sydney Golf Club', subtitle: 'Rose Bay, NSW'),
    _Course(id: 'rq', name: 'Royal Queensland Golf Club', subtitle: 'Eagle Farm, QLD'),
  ];

  @override
  void initState() {
    super.initState();
    _eventTabController = TabController(length: 2, vsync: this);
    _events = [
      _EventRow(
        id: 'birdie',
        name: 'Birdie',
        description: 'Awarded for completing the hole in 1 under par.',
        defaultPoints: 1,
      ),
      _EventRow(
        id: 'eagle',
        name: 'Eagle',
        description: 'Awarded for completing the hole in 2 under par.',
        defaultPoints: 2,
      ),
      _EventRow(
        id: 'chip',
        name: 'Chip-in',
        description: 'Holed out from off the green.',
        defaultPoints: 2,
      ),
      _EventRow(
        id: 'greenie',
        name: 'Greenie',
        description: 'Hit the green in regulation and two-putt or better.',
        defaultPoints: 1,
      ),
      _EventRow(
        id: 'three',
        name: 'Three-putt',
        description: 'Three or more putts on the green.',
        defaultPoints: -1,
      ),
    ];
    for (final e in _events) {
      e.resetPoints();
    }
    unawaited(_loadPlayersFromSupabase());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _eventTabController.dispose();
    super.dispose();
  }

  String get _stepLabel => switch (_step) {
        0 => "WHO'S PLAYING?",
        1 => 'COURSE SELECTION',
        2 => 'GAME EVENTS',
        _ => 'REVIEW',
      };

  Iterable<_Course> get _filteredCourses {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _courses;
    return _courses.where(
      (c) =>
          c.name.toLowerCase().contains(q) || c.subtitle.toLowerCase().contains(q),
    );
  }

  _Course? get _selectedCourse {
    if (_selectedCourseId == null) return null;
    try {
      return _courses.firstWhere((c) => c.id == _selectedCourseId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAddPlayer() async {
    await showAddPlayerSheet(
      context,
      onAdd: (name, email) {
        setState(() {
          final id = 'p_${DateTime.now().millisecondsSinceEpoch}';
          _players.add(_Player(id: id, name: name));
          if (email != null && email.isNotEmpty) {
            // Stub: would sync to Supabase
          }
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
      final rows = await client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .limit(1);
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
        ..add(_Player(id: 'you_${user.id}', name: displayName, isYou: true));
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
    final course = _selectedCourse!;
    final result = await showCourseSetupSheet(context, courseName: course.name);
    if (!mounted || result == null) return;
    setState(() {
      _courseSetup = result;
      _step = 2;
    });
  }

  void _addCustomEvent() async {
    final draft = await showAddCustomEventSheet(context);
    if (!mounted || draft == null) return;
    setState(() {
      final row = _EventRow(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        name: draft.name,
        description: draft.description,
        defaultPoints: draft.points,
        isCustom: true,
      );
      row.points = draft.points;
      row.enabled = true;
      _events.add(row);
      _eventTabController.index = 1;
    });
  }

  String _shortCourseTitle(_Course c) {
    return switch (c.id) {
      'rm' => 'Royal Melbourne',
      'rs' => 'Royal Sydney',
      'rq' => 'Royal Queensland',
      _ => c.name.split(',').first.trim(),
    };
  }

  Future<void> _goHoleScoring() async {
    if (_startingRound) return;
    final course = _selectedCourse!;
    final setup = _courseSetup!;
    final startHole = setup.holes == 9 ? (setup.frontNineFirst ? 1 : 10) : 1;
    String? roundId;
    if (SupabaseEnv.isConfigured && Supabase.instance.client.auth.currentUser != null) {
      setState(() => _startingRound = true);
      try {
        roundId = await HistoryRepository.createInProgressRound(
          courseName: course.name,
          courseShortTitle: _shortCourseTitle(course),
          holeCount: setup.holes,
          players: _players.map((p) => p.name).toList(),
          currentHole: startHole,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start synced round: $e')),
        );
      } finally {
        if (mounted) setState(() => _startingRound = false);
      }
    }
    final args = RoundSessionArgs(
      courseName: course.name,
      courseShortTitle: _shortCourseTitle(course),
      holeCount: setup.holes,
      startHole: startHole,
      playerNames: _players.map((p) => p.name).toList(),
      roundId: roundId,
      currentHole: startHole,
      initialScoreByPlayer: {for (final p in _players) p.name: 0},
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
          onPressed: () => Navigator.of(context).pop(),
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
            child: switch (_step) {
              0 => FilledButton(
                  onPressed: _loadingPlayers || _players.isEmpty
                      ? null
                      : () => setState(() => _step = 1),
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
                },
              ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        ..._filteredCourses.map((c) {
          final selected = _selectedCourseId == c.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space25),
            child: Material(
              color: scheme.surface.withValues(alpha: 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                onTap: () => setState(() => _selectedCourseId = c.id),
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
                              c.subtitle,
                              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
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
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Manual course entry — coming soon')),
            );
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _eventTabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'Preset events'),
            Tab(text: 'Custom events'),
          ],
        ),
        const SizedBox(height: AppTheme.space2),
        Expanded(
          child: TabBarView(
            controller: _eventTabController,
            children: [
              _eventList(_events.where((e) => !e.isCustom).toList(), scheme, text),
              _eventList(_events.where((e) => e.isCustom).toList(), scheme, text, emptyCustom: true),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space2),
        OutlinedButton.icon(
          onPressed: _addCustomEvent,
          icon: Icon(Icons.add, color: scheme.primary),
          label: Text('Add custom event', style: TextStyle(color: scheme.primary)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: scheme.primary.withValues(alpha: AppTheme.opacityBorderEmphasis),
              width: AppTheme.chipOutlineWidth,
            ),
          ),
        ),
      ],
    );
  }

  Widget _eventList(
    List<_EventRow> rows,
    ColorScheme scheme,
    TextTheme text, {
    bool emptyCustom = false,
  }) {
    if (rows.isEmpty && emptyCustom) {
      return Center(
        child: Text(
          'No custom events yet.\nTap “Add custom event” below.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      children: rows
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: OutlinedSurfaceCard(
                borderColor: scheme.outlineVariant,
                padding: const EdgeInsets.all(AppTheme.buttonPadV),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Switch(
                          value: e.enabled,
                          onChanged: (v) => setState(() => e.enabled = v),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: AppTheme.space1),
                              Text(
                                e.description,
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: AppTheme.bodyLineHeightTight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton.filledTonal(
                          onPressed: e.enabled
                              ? () => setState(() => e.points = (e.points - 1).clamp(-5, 10))
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
                          child: Text(
                            e.points >= 0 ? '+${e.points}' : '${e.points}',
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: e.enabled
                              ? () => setState(() => e.points = (e.points + 1).clamp(-5, 10))
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final course = _selectedCourse;
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
                  '${setup.holes} holes · ${setup.frontNineFirst ? 'Front' : 'Back'} 9 · ${setup.teeLabel} tees',
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
