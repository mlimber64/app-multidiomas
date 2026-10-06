import '../../../core/errors/failure.dart';
import '../../../l10n/l10n.dart';

/// Friendly copy for each failure kind, in the current UI language. Provider details, HTTP codes
/// and keys never reach the UI.
extension AIFailureCopy on AIFailure {
  String userMessage(AppLocalizations l) => switch (kind) {
    AIFailureKind.notConfigured => l.aiNotConfigured,
    AIFailureKind.network => l.aiNetwork,
    AIFailureKind.rateLimited => l.aiRateLimited,
    AIFailureKind.blocked ||
    AIFailureKind.invalidResponse ||
    AIFailureKind.unknown => l.chatErrorGeneric,
  };
}
