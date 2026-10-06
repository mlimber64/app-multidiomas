import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l10n.someText`: the interface text in the current UI language.
extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
