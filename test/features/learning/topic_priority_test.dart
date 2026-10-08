import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_overview.dart';
import 'package:parla_con_me/features/learning/presentation/widgets/topic_tile.dart';
import 'package:parla_con_me/l10n/l10n.dart';

Widget _tile(int ok, int total, {int? rank = 1}) => MaterialApp(
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: TopicTile(
      rank: rank,
      onTap: () {},
      view: TopicView(
        topic: GrammarTopic.essereVsAvere,
        standing: TopicStanding.toReinforce,
        successfulUses: ok,
        appearances: total,
      ),
    ),
  ),
);

void main() {
  testWidgets('la prioridad sale de la parte de usos correctos', (t) async {
    await t.pumpWidget(_tile(0, 4));
    expect(find.text('Alta'), findsOneWidget);
    await t.pumpWidget(_tile(2, 4));
    expect(find.text('Media'), findsOneWidget);
    await t.pumpWidget(_tile(4, 5));
    expect(find.text('Baja'), findsOneWidget);
  });

  testWidgets('sin puesto en la lista no hay prioridad', (t) async {
    await t.pumpWidget(_tile(0, 4, rank: null));
    expect(find.text('Alta'), findsNothing);
  });
}
