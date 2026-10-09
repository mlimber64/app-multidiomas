import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../features/profile/presentation/ui_language_providers.dart';
import '../features/reminders/presentation/reminder_scheduler.dart';
import '../l10n/l10n.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class ParlaConMeApp extends ConsumerWidget {
  const ParlaConMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The daily reminders follow the learner's practice for as long as the app
    // lives; watching the scheduler is what starts it.
    ref.watch(reminderSchedulerProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // NUEVO: el rediseño es solo claro; el tema oscuro queda como estaba.
      themeMode: ThemeMode.light,
      locale: ref.watch(appLocaleProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
