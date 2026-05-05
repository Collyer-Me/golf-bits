import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../data/friends_repository.dart';
import '../models/friend_models.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'log_in_screen.dart';
import 'sign_up_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = true;
  bool _searching = false;
  List<FriendConnection> _connections = const [];
  List<CoplayerSummary> _coplayers = const [];
  List<FriendCandidate> _searchResults = const [];

  /// Non-null while a friendship mutation is in flight (disables repeat taps).
  String? _blockingFriendshipId;

  String? get _uid => SupabaseEnv.isConfigured ? Supabase.instance.client.auth.currentUser?.id : null;

  static bool _isAnonymousUser(User? user) {
    if (user == null) return false;
    final provider = user.appMetadata['provider'];
    return provider == 'anonymous';
  }

  bool get _anonymousFindBlocked {
    if (!SupabaseEnv.isConfigured) return false;
    return _isAnonymousUser(Supabase.instance.client.auth.currentUser);
  }

  Future<void> _onPullRefresh() async {
    await _loadOverview();
    if (_searchController.text.trim().length >= 2) {
      await _runSearch();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadOverview());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    if (!SupabaseEnv.isConfigured || _uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    List<FriendConnection> data = const [];
    try {
      data = await FriendsRepository.fetchOverview();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load friends: $e')),
        );
      }
      data = const [];
    }
    List<CoplayerSummary> coplayers = const [];
    try {
      coplayers = await FriendsRepository.fetchCoplayerSummaries(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load people from round history: $e')),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _connections = data;
      _coplayers = coplayers;
      _loading = false;
    });
  }

  void _onSearchChanged() {
    if (_anonymousFindBlocked) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch());
    });
    setState(() {});
  }

  Future<void> _runSearch() async {
    if (_anonymousFindBlocked) return;
    final query = _searchController.text.trim();
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchResults = const [];
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await FriendsRepository.searchCandidates(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  bool _isAlreadyConnectedOrPending(String otherUserId) {
    return _connections.any((f) => f.otherUserId == otherUserId && f.status != 'declined');
  }

  Future<void> _sendRequest(String otherUserId) async {
    try {
      final ok = await FriendsRepository.sendFriendRequest(otherUserId);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send friend request. Try again.')),
        );
        return;
      }
      await _loadOverview();
      unawaited(_runSearch());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    }
  }

  Future<void> _acceptRequest(String friendshipId) async {
    setState(() => _blockingFriendshipId = friendshipId);
    try {
      final ok = await FriendsRepository.acceptRequest(friendshipId);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept — request may have expired.')),
        );
        await _loadOverview();
        return;
      }
      await _loadOverview();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept: $e')),
      );
    } finally {
      if (mounted) setState(() => _blockingFriendshipId = null);
    }
  }

  Future<void> _declineRequest(String friendshipId) async {
    setState(() => _blockingFriendshipId = friendshipId);
    try {
      final ok = await FriendsRepository.declineRequest(friendshipId);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not decline — try refreshing.')),
        );
        await _loadOverview();
        return;
      }
      await _loadOverview();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not decline: $e')),
      );
    } finally {
      if (mounted) setState(() => _blockingFriendshipId = null);
    }
  }

  Future<void> _removeFriend(String friendshipId) async {
    setState(() => _blockingFriendshipId = friendshipId);
    try {
      final ok = await FriendsRepository.removeFriend(friendshipId);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove friend. Try again.')),
        );
        return;
      }
      await _loadOverview();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove: $e')),
      );
    } finally {
      if (mounted) setState(() => _blockingFriendshipId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseEnv.isConfigured;
    final user = configured ? Supabase.instance.client.auth.currentUser : null;

    if (!configured || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('People')),
        body: _authGateBody(needsConfig: !configured),
      );
    }

    final uid = _uid!;
    final accepted = _connections.where((f) => f.isAccepted).toList();
    final incoming = _connections.where((f) => f.isIncomingFor(uid)).toList();
    final outgoing = _connections.where((f) => f.isOutgoingFor(uid)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Friends'),
                    Tab(text: 'Requests'),
                    Tab(text: 'Find'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _wrapRefresh(_friendsTab(accepted, _coplayers)),
                      _wrapRefresh(_requestsTab(incoming, outgoing)),
                      _wrapRefresh(_findTab()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _wrapRefresh(Widget child) {
    return RefreshIndicator(
      onRefresh: _onPullRefresh,
      child: child,
    );
  }

  Widget _authGateBody({required bool needsConfig}) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: AppTheme.screenPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: OutlinedSurfaceCard(
            borderColor: scheme.outlineVariant,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  needsConfig ? 'Cloud not connected' : 'Sign in to use People',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AppTheme.space3),
                Text(
                  needsConfig
                      ? 'This build is not connected to Supabase, so friend search and requests are unavailable.'
                      : 'Create an account or log in to find people, send friend requests, and see requests from others.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (!needsConfig) ...[
                  SizedBox(height: AppTheme.space6),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(builder: (_) => const LogInScreen()),
                      );
                    },
                    child: const Text('Log in'),
                  ),
                  SizedBox(height: AppTheme.space3),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: const Text('Create account'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _friendsTab(List<FriendConnection> accepted, List<CoplayerSummary> coplayers) {
    if (accepted.isEmpty && coplayers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppTheme.screenPadding,
        children: [
          _emptyState(
            'No people here yet',
            'Play a round with others, or use Find to add friends by account. People from your rounds appear here even without an email.',
          ),
        ],
      );
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppTheme.screenPadding,
      children: [
        if (coplayers.isNotEmpty) ...[
          Text(
            'People you have played with',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.spaceHalf),
          Text(
            'These names come from your saved rounds. They are not linked to an account in the app unless you add them in Find.',
            style: muted,
          ),
          const SizedBox(height: AppTheme.space3),
          for (final c in coplayers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: OutlinedSurfaceCard(
                borderColor: scheme.outlineVariant,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.displayName, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTheme.spaceHalf),
                    Text(
                      '${c.roundsPlayed} ${c.roundsPlayed == 1 ? 'round' : 'rounds'} · no linked account or email on file',
                      style: muted,
                    ),
                  ],
                ),
              ),
            ),
          if (accepted.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space5),
            Text(
              'Friends',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.space3),
          ],
        ],
        for (final friend in accepted)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space3),
            child: OutlinedSurfaceCard(
              borderColor: scheme.outlineVariant,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(friend.otherDisplayName, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: AppTheme.spaceHalf),
                        Text(
                          (friend.otherEmail != null && friend.otherEmail!.trim().isNotEmpty)
                              ? friend.otherEmail!.trim()
                              : 'No email on file for this friend.',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove friend',
                    onPressed: _blockingFriendshipId != null
                        ? null
                        : () => _removeFriend(friend.friendshipId),
                    icon: _blockingFriendshipId == friend.friendshipId
                        ? SizedBox(
                            width: AppTheme.iconDense,
                            height: AppTheme.iconDense,
                            child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                          )
                        : const Icon(Icons.person_remove_outlined),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _requestsTab(List<FriendConnection> incoming, List<FriendConnection> outgoing) {
    if (incoming.isEmpty && outgoing.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppTheme.screenPadding,
        children: [
          _emptyState('No pending requests', 'Incoming and outgoing requests will appear here.'),
        ],
      );
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppTheme.screenPadding,
      children: [
        if (incoming.isNotEmpty) ...[
          Text('Incoming', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTheme.space2),
          for (final item in incoming)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: OutlinedSurfaceCard(
                borderColor: scheme.outlineVariant,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.otherDisplayName, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTheme.space3),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _blockingFriendshipId != null
                                ? null
                                : () => _declineRequest(item.friendshipId),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space3),
                        Expanded(
                          child: FilledButton(
                            onPressed: _blockingFriendshipId != null
                                ? null
                                : () => _acceptRequest(item.friendshipId),
                            child: _blockingFriendshipId == item.friendshipId
                                ? SizedBox(
                                    height: AppTheme.iconInline,
                                    width: AppTheme.iconInline,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (outgoing.isNotEmpty) ...[
          SizedBox(height: incoming.isNotEmpty ? AppTheme.space3 : 0),
          Text('Outgoing', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTheme.space2),
          for (final item in outgoing)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: OutlinedSurfaceCard(
                borderColor: scheme.outlineVariant,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item.otherDisplayName, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      'Pending',
                      style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _findTab() {
    if (_anonymousFindBlocked) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppTheme.screenPadding,
        children: [
          OutlinedSurfaceCard(
            borderColor: scheme.outlineVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Find needs a full account',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AppTheme.space3),
                Text(
                  'Guest mode cannot search by email or name. Create a free account to find people and send friend requests.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                SizedBox(height: AppTheme.space6),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                    );
                  },
                  child: const Text('Create account'),
                ),
                SizedBox(height: AppTheme.space3),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const LogInScreen()),
                    );
                  },
                  child: const Text('Log in with email'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppTheme.screenPadding,
      children: [
        SearchBar(
          controller: _searchController,
          hintText: 'Search by name or email',
          leading: const Icon(Icons.search),
          trailing: [
            if (_searchController.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchResults = const []);
                },
                icon: const Icon(Icons.clear),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.space3),
        if (_searchController.text.trim().length < 2)
          Text(
            'Type at least 2 characters to search.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          )
        else if (_searching)
          const Center(child: CircularProgressIndicator())
        else if (_searchResults.isEmpty)
          Text(
            'No users found.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          ..._searchResults.map(
            (candidate) {
              final disabled = _isAlreadyConnectedOrPending(candidate.userId);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space3),
                child: OutlinedSurfaceCard(
                  borderColor: scheme.outlineVariant,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              candidate.displayName,
                              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              (candidate.email != null && candidate.email!.trim().isNotEmpty)
                                  ? candidate.email!.trim()
                                  : 'No email on file for this profile.',
                              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: disabled ? null : () => _sendRequest(candidate.userId),
                        child: Text(disabled ? 'Added' : 'Add'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _emptyState(String title, String subtitle) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppTheme.space2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
