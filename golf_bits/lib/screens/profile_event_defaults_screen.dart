import 'dart:async';

import 'package:flutter/material.dart';

import '../data/user_preferences_repository.dart';
import '../models/event_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/event_preferences_editor.dart';

class ProfileEventDefaultsScreen extends StatefulWidget {
  const ProfileEventDefaultsScreen({super.key});

  @override
  State<ProfileEventDefaultsScreen> createState() => _ProfileEventDefaultsScreenState();
}

class _ProfileEventDefaultsScreenState extends State<ProfileEventDefaultsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<EventPreference> _events = defaultEventPreferences();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final events = await UserPreferencesRepository.fetchDefaultEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await UserPreferencesRepository.saveDefaultEvents(_events);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default event settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save defaults: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Default Event Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: AppTheme.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'This uses the same event builder as New Round. Changes here are your defaults for future rounds.',
                    style: text.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space3),
                  Expanded(
                    child: EventPreferencesEditor(
                      events: _events,
                      onChanged: (next) => setState(() => _events = next),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: AppTheme.screenPadding.copyWith(top: AppTheme.space2),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: AppTheme.iconInline,
                    height: AppTheme.iconInline,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Text('Save defaults'),
          ),
        ),
      ),
    );
  }
}
