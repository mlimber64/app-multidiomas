import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/ui/ui.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../daily_routine/presentation/daily_routine_controller.dart';
import '../../daily_routine/presentation/practice_activity.dart';
import '../../daily_routine/presentation/widgets/routine_card.dart';
import '../../learning/presentation/learning_labels.dart';
import '../../learning/presentation/learning_providers.dart';
import '../../profile/domain/user_learning_profile.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../profile/presentation/profile_labels.dart';

/// Hub of the app: greeting, today's practice, the main call to action, quick
/// access to the areas, and the learner's saved preferences.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userLearningProfileProvider);
    final l = context.l10n;
    const step = Duration(milliseconds: 70);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              FadeSlideIn(
                child: ScreenHeader(
                  title: l.homeGreeting,
                  subtitle: l.homeReady,
                  trailing: const _StreakChip(),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(delay: step, child: const RoutineCard()),
              const SizedBox(height: 14),
              FadeSlideIn(delay: step * 2, child: const _TalkCard()),
              const SizedBox(height: 14),
              FadeSlideIn(delay: step * 3, child: const _QuickGrid()),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: step * 4,
                child: _JourneyStrip(profile: profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// NUEVO: chip de racha de la cabecera. Solo aparece cuando hay una racha
// (no se muestra un "0 días" que desanime).
class _StreakChip extends ConsumerWidget {
  const _StreakChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(practiceActivityProvider).value?.streak ?? 0;
    if (streak == 0) return const SizedBox.shrink();
    final l = context.l10n;
    return Semantics(
      label: l.streakLabel(streak),
      excludeSemantics: true,
      child: StatusChip(
        label: l.homeStreakDays(streak),
        icon: Icons.local_fire_department,
        iconSize: 18,
        background: AppColors.amberBg,
        foreground: AppColors.amberText,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
      ),
    );
  }
}

// NUEVO: tarjeta "Hablemos", la acción principal de la pantalla: degradado
// verde con texto blanco para que destaque sobre las tarjetas crema. Toda la
// tarjeta lleva a Hablar.
class _TalkCard extends StatelessWidget {
  const _TalkCard();

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.greenDark, AppColors.green, Color(0xFF2C7A57)],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      gradient: _gradient,
      borderColor: Colors.transparent,
      shadow: AppShadows.talk,
      onTap: () => context.go(AppRoutes.conversation),
      semanticLabel: '${l.letsTalk}. ${l.heroSubtitle}',
      child: Row(
        children: [
          const IconCircle(
            icon: Icons.graphic_eq,
            size: 52,
            iconSize: 28,
            background: AppColors.mint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.letsTalk,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.heroSubtitle,
                  style: AppTextStyles.body.copyWith(color: AppColors.mint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const IconCircle(
            icon: Icons.arrow_forward,
            size: 44,
            iconSize: 22,
            background: Colors.white,
            foreground: AppColors.green,
          ),
        ],
      ),
    );
  }
}

// NUEVO: cuadrícula 2 × 2 de accesos: cada uno con su color y un subtítulo
// con datos reales (áreas por reforzar, ejercicios pendientes, palabras).
class _QuickGrid extends ConsumerWidget {
  const _QuickGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final overview = ref.watch(learningOverviewProvider).value;
    final routine = ref.watch(dailyRoutineProvider).value;
    final areas = overview?.toReinforce.length ?? 0;
    final words = overview?.vocabularyToConsolidate.length ?? 0;
    final pending = routine?.step1.itemIds.length ?? 0;

    final tiles = [
      _Tile(
        icon: Icons.chat_bubble_outline,
        background: AppColors.feedbackBg,
        foreground: AppColors.feedbackAccent,
        title: l.quickConversation,
        subtitle: l.homeTileConversationSub,
        onTap: () => context.go(AppRoutes.conversation),
      ),
      _Tile(
        icon: Icons.school_outlined,
        background: AppColors.mint,
        foreground: AppColors.greenDark,
        title: l.navLearn,
        subtitle: areas > 0 ? l.homeTileLearnSub(areas) : l.homeTileLearnNone,
        onTap: () => context.go(AppRoutes.learning),
      ),
      _Tile(
        icon: Icons.replay,
        background: AppColors.amberBg,
        foreground: AppColors.amberText,
        title: l.quickReview,
        subtitle: pending > 0
            ? l.homeTileReviewSub(pending)
            : l.homeTileReviewNone,
        // "Repasar" abre la sesión de repaso por encima de la barra.
        onTap: () => context.push(AppRoutes.review),
      ),
      _Tile(
        icon: Icons.menu_book_outlined,
        background: AppColors.terraBg,
        foreground: AppColors.terraText,
        title: l.navWords,
        subtitle: words > 0 ? l.homeTileWordsSub(words) : l.homeTileWordsNone,
        onTap: () => context.go(AppRoutes.vocabulary),
      ),
    ];
    Widget row(int start) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tiles[start]),
          const SizedBox(width: 12),
          Expanded(child: tiles[start + 1]),
        ],
      ),
    );
    return Column(children: [row(0), const SizedBox(height: 12), row(2)]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // NUEVO: fondo crema suave, borde de 1 px (el de AppCard) e icono en un
    // círculo del color de cada área, para reconocerlas de un vistazo.
    return AppCard(
      radius: AppRadius.tile,
      padding: const EdgeInsets.all(14),
      color: AppColors.surfaceCream,
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      child: Row(
        children: [
          ExcludeSemantics(
            child: IconCircle(
              icon: icon,
              size: 42,
              background: background,
              foreground: foreground,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: AppTextStyles.rowTitle),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.small.copyWith(
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// NUEVO: "Tu recorrido": las preferencias guardadas (idioma, nivel, enfoque)
// como tarjetitas con un icono propio, en una fila que se desliza cuando no
// caben en el ancho del teléfono. Son los mismos datos que Inicio ya mostraba.
class _JourneyStrip extends StatelessWidget {
  const _JourneyStrip({required this.profile});

  final UserLearningProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final level = profile.level?.label(l).replaceAll(' — ', ' · ');
    final focus = joinLabels(
      l,
      LearningFocus.values,
      profile.focusAreas,
      (f) => f.label(l),
    );
    final items = [
      (
        Icons.translate,
        AppColors.mint,
        AppColors.greenDark,
        profile.learningLanguage.label,
      ),
      if (level != null)
        (
          Icons.signal_cellular_alt,
          AppColors.amberBg,
          AppColors.amberText,
          level,
        ),
      (
        Icons.track_changes,
        AppColors.feedbackBg,
        AppColors.feedbackAccent,
        focus,
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l.journeyTitle.toUpperCase(),
              style: AppTextStyles.eyebrow,
            ),
          ),
          const SizedBox(height: 10),
          // Horizontal scroll: the cards keep their natural width instead of
          // squeezing or wrapping on narrow phones.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _JourneyItem(
                    icon: item.$1,
                    background: item.$2,
                    foreground: item.$3,
                    text: item.$4,
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _LearningNote(),
          ),
        ],
      ),
    );
  }
}

class _JourneyItem extends StatelessWidget {
  const _JourneyItem({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.text,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: IconCircle(
              icon: icon,
              size: 30,
              iconSize: 16,
              background: background,
              foreground: foreground,
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.chip.copyWith(color: AppColors.ink)),
        ],
      ),
    ),
  );
}

// NUEVO: lo que la app ha aprendido hasta ahora, en un bloque pequeño dentro
// de "Tu recorrido": una invitación mientras no hay nada y, después, el foco
// actual y lo que mejora. Mientras carga, o si no se puede leer, no muestra
// nada: Inicio nunca se bloquea ni se queja por ello.
class _LearningNote extends ConsumerWidget {
  const _LearningNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final overview = ref.watch(learningOverviewProvider).value;
    if (overview == null) return const SizedBox.shrink();
    if (overview.isEmpty) {
      return _NoteBlock(title: l.noteStartTitle, lines: [l.noteStartBody]);
    }
    if (!overview.hasTopics) return const SizedBox.shrink();

    final focus = overview.toReinforce.firstOrNull;
    final improving = overview.improving
        .take(2)
        .map((t) => t.topic.label(l))
        .toList();
    return _NoteBlock(
      title: focus != null ? l.noteFocusTitle : l.noteImprovingTitle,
      onTap: () => context.go(AppRoutes.progress),
      lines: [
        if (focus != null) ...[focus.topic.label(l), l.noteKeepPracticing],
        if (focus == null) improving.join(', '),
        if (focus != null && improving.isNotEmpty)
          l.noteImprovingIn(improving.join(', ')),
      ],
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.title, required this.lines, this.onTap});

  final String title;
  final List<String> lines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.rowTitle),
                        for (final line in lines) ...[
                          const SizedBox(height: 4),
                          Text(line, style: AppTextStyles.body),
                        ],
                      ],
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
