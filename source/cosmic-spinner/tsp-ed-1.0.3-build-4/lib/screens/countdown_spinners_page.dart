import 'package:flutter/material.dart';

import '../models/countdown_spinner_session.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cosmic_scaffold.dart';

/// Shell for the future Countdown Spinners tab.
///
/// This page is intentionally not linked from the live interface until
/// verdict acceptance, elimination, and persistence are implemented together.
class CountdownSpinnersPage extends StatelessWidget {
  const CountdownSpinnersPage({
    super.key,
    required this.controller,
    this.sessions = const <CountdownSpinnerSession>[],
  });

  final AppController controller;
  final List<CountdownSpinnerSession> sessions;

  @override
  Widget build(BuildContext context) {
    return CosmicScaffold(
      controller: controller,
      body: ListView(
        key: const Key('countdown-spinners-page'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: <Widget>[
          Text(
            'Countdown Spinners',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.frogYellow,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Countdown copies will live here while their original saved spinners stay unchanged.',
          ),
          if (sessions.isEmpty) ...<Widget>[
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No countdown spinner has entered the cosmos yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 18),
            for (final session in sessions)
              Card(
                child: ListTile(
                  title: Text(
                    session.title.trim().isEmpty
                        ? '(Untitled Countdown)'
                        : session.title,
                  ),
                  subtitle: Text(
                    '${session.remainingCount} choice${session.remainingCount == 1 ? '' : 's'} remaining',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
