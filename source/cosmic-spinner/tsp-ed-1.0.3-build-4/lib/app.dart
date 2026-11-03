// ////Block One//////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'services/app_controller.dart';
import 'theme/app_theme.dart';

class CosmicSpinnerApp extends StatefulWidget {
  const CosmicSpinnerApp({super.key});

  @override
  State<CosmicSpinnerApp> createState() => _CosmicSpinnerAppState();
}

class _CosmicSpinnerAppState extends State<CosmicSpinnerApp> {
  late final AppController controller = AppController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cosmic Spinner',
      theme: buildAppTheme(),
      builder: (context, child) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.loaded) {
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: controller.loading
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                controller.loadError ??
                                    'Unable to load spinners.',
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: controller.retryLoad,
                                child: const Text('Retry loading'),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            );
          }
          final message = controller.saveError ?? controller.recoveryWarning;
          return Column(
            children: [
              if (message != null)
                Material(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(message),
                          if (controller.saveError != null)
                            TextButton(
                              onPressed: controller.saving
                                  ? null
                                  : controller.retrySave,
                              child: Text(
                                controller.saving ? 'Saving…' : 'Retry saving',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(child: child!),
            ],
          );
        },
      ),
      home: HomePage(controller: controller),
    );
  }
}
