import 'package:flutter_test/flutter_test.dart';
import 'package:parla_con_me/features/learning/domain/grammar_topic.dart';
import 'package:parla_con_me/features/learning/domain/learning_state.dart';
import 'package:parla_con_me/features/learning/domain/practice_evidence.dart';
import 'package:parla_con_me/features/learning/domain/user_vocabulary.dart';

// Phase 11B: the learning state of ONE concept, from structured evidence.

const _production = PracticeEvidenceType.production;
const _recognition = PracticeEvidenceType.recognition;
const _exposure = PracticeEvidenceType.exposure;

/// A step of evidence: production by default; `c` is the interaction.
typedef Step = ({PracticeEvidenceType type, bool ok, String? ctx});

Step ok([String? ctx]) => (type: _production, ok: true, ctx: ctx);
Step ko([String? ctx]) => (type: _production, ok: false, ctx: ctx);
Step pick(bool ok) => (type: _recognition, ok: ok, ctx: null);

PracticeProof _proof(List<Step> steps) {
  var proof = PracticeProof.empty;
  for (final s in steps) {
    proof = proof.record(type: s.type, success: s.ok, context: s.ctx);
  }
  return proof;
}

LearningState _state(List<Step> steps, {bool hadDifficulty = false}) =>
    _proof(steps).stateOf(hadDifficulty: hadDifficulty);

void main() {
  group('states', () {
    test('a concept with no evidence is NEW', () {
      expect(PracticeProof.empty.isEmpty, isTrue);
      expect(_state([]), LearningState.newConcept);
      expect(PracticeProof.empty.productionProven, isFalse);
    });

    test('NEW -> WEAK on a production error', () {
      expect(_state([ko('a')]), LearningState.weak);
    });

    test('a mistake already known (conversation history) makes it WEAK', () {
      expect(_state([], hadDifficulty: true), LearningState.weak);
    });

    test('CONSOLIDATED is only reached from IMPROVING: never from NEW or '
        'WEAK in one step', () {
      // Every sequence of up to 7 pieces of evidence, from nothing.
      final alphabet = [ok('a'), ok('b'), ko('a'), pick(true), pick(false)];
      var checked = 0;
      void walk(List<Step> steps, LearningState before) {
        if (steps.length == 7) return;
        for (final next in alphabet) {
          final all = [...steps, next];
          final after = _state(all);
          if (after == LearningState.consolidated) {
            expect(
              before,
              anyOf(LearningState.improving, LearningState.consolidated),
              reason: 'jumped from $before to $after after ${all.length} steps',
            );
          }
          checked++;
          walk(all, after);
        }
      }

      walk([], LearningState.newConcept);
      expect(checked, greaterThan(10000));
    });

    test('NEW -> IMPROVING needs two correct productions, not one', () {
      expect(_state([ok('a')]), LearningState.newConcept);
      expect(_state([ok('a'), ok('b')]), LearningState.improving);
    });

    test('WEAK -> IMPROVING needs at least two correct productions', () {
      expect(_state([ko('a'), ok('a')]), LearningState.weak);
      expect(_state([ko('a'), ok('a'), ok('b')]), LearningState.improving);
    });

    test('WEAK stays WEAK while the difficulty goes on', () {
      expect(_state([ko('a'), ko('a'), ok('b')]), LearningState.weak);
      expect(_state([ko('a'), ko('b'), ko('c'), ok('d')]), LearningState.weak);
    });

    test('IMPROVING stays IMPROVING with insufficient evidence', () {
      // Two correct ones: not enough to consolidate.
      expect(_state([ko('a'), ok('a'), ok('b')]), LearningState.improving);
      // Three correct ones, but all in one interaction.
      expect(
        _state([ko('a'), ok('a'), ok('a'), ok('a')]),
        LearningState.improving,
      );
    });

    test('IMPROVING -> CONSOLIDATED: three correct productions in two '
        'interactions', () {
      final steps = [ko('a'), ok('a'), ok('b'), ok('b')];
      expect(_state(steps.take(3).toList()), LearningState.improving);
      expect(_state(steps), LearningState.consolidated);
    });

    test('CONSOLIDATED tolerates an isolated error', () {
      final base = [ok('a'), ok('b'), ok('c')];
      expect(_state(base), LearningState.consolidated);
      expect(_state([...base, ko('d')]), LearningState.consolidated);
      expect(_state([...base, ko('d'), ok('e')]), LearningState.consolidated);
      expect(
        _state([ok('a'), ok('b'), ko('c'), ok('d')]),
        LearningState.consolidated,
      );
    });

    test('CONSOLIDATED degrades to IMPROVING after a clear recent collapse '
        'with a good history', () {
      final state = _state([ok('a'), ok('b'), ok('c'), ko('d'), ko('e')]);
      expect(state, LearningState.improving);
    });

    test('CONSOLIDATED degrades to WEAK when failures outnumber successes', () {
      final steps = [ok('a'), ok('b'), ok('c'), ko('d'), ko('e'), ko('f')];
      expect(_state(steps), LearningState.weak);
    });

    test('a degraded concept recovers step by step', () {
      final lost = [ok('a'), ok('b'), ok('c'), ko('d'), ko('e'), ko('f')];
      expect(_state(lost), LearningState.weak);
      // Two correct ones do not yet outweigh three recent failures.
      expect(_state([...lost, ok('g'), ok('h')]), LearningState.weak);
      expect(
        _state([...lost, ok('g'), ok('h'), ok('i')]),
        LearningState.improving,
      );
      // Back to a calm record: at most one failure among the last five.
      expect(
        _state([...lost, ok('g'), ok('h'), ok('i'), ok('j')]),
        LearningState.consolidated,
      );
    });
  });

  group('recognition is not production', () {
    test('recognition alone never proves production', () {
      final proof = _proof([for (var i = 0; i < 20; i++) pick(true)]);
      expect(proof.recognitionSuccesses, 20);
      expect(proof.productionSuccesses, 0);
      expect(proof.productionProven, isFalse);
      expect(proof.contexts, isEmpty);
    });

    test('recognition alone never leaves NEW or WEAK', () {
      final many = [for (var i = 0; i < 20; i++) pick(true)];
      expect(_state(many), LearningState.newConcept);
      expect(_state(many, hadDifficulty: true), LearningState.weak);
    });

    test('recognition never consolidates, whatever else came with it', () {
      // One correct production plus any amount of recognition.
      final steps = [ok('a'), for (var i = 0; i < 20; i++) pick(true)];
      final proof = _proof(steps);
      expect(proof.productionProven, isFalse);
      expect(proof.stateOf(hadDifficulty: true), LearningState.weak);
      expect(proof.stateOf(hadDifficulty: false), LearningState.newConcept);
    });

    test('a failed recognition is a difficulty', () {
      expect(_state([pick(false)]), LearningState.weak);
    });

    test('recognition does not enter the recent productions nor the '
        'interactions', () {
      final proof = _proof([ok('a'), pick(true), pick(false)]);
      expect(proof.recent, [true]);
      expect(proof.contexts, ['a']);
    });

    test('production counts: right and wrong ones are both recorded', () {
      final proof = _proof([ok('a'), ok('a'), ko('b'), pick(true)]);
      expect(proof.productionSuccesses, 2);
      expect(proof.productionFailures, 1);
      expect(proof.recognitionSuccesses, 1);
      expect(proof.recognitionFailures, 0);
      expect(proof.recent, [true, true, false]);
    });

    test('mere exposure says nothing about command', () {
      final seen = PracticeProof.empty.record(type: _exposure, success: true);
      expect(seen, PracticeProof.empty);
    });
  });

  group('interactions', () {
    test('three correct answers in one interaction are one context', () {
      final proof = _proof([ok('a'), ok('a'), ok('a')]);
      expect(proof.productionSuccesses, 3);
      expect(proof.contexts, ['a']);
      expect(proof.stateOf(hadDifficulty: false), LearningState.improving);
    });

    test('correct answers spread over two interactions can consolidate', () {
      final proof = _proof([ok('a'), ok('a'), ok('b')]);
      expect(proof.contexts, ['a', 'b']);
      expect(proof.stateOf(hadDifficulty: false), LearningState.consolidated);
    });

    test(
      'evidence that does not say where it came from is one interaction',
      () {
        final proof = _proof([ok(), ok(), ok(), ok()]);
        expect(proof.contexts, [LearningStatePolicy.unknownContext]);
        expect(proof.stateOf(hadDifficulty: false), LearningState.improving);
      },
    );

    test('only correct productions open an interaction', () {
      final proof = _proof([ko('a'), ko('b'), ok('c')]);
      expect(proof.contexts, ['c']);
    });

    test('the remembered interactions and outcomes are bounded', () {
      final proof = _proof([for (var i = 0; i < 30; i++) ok('c$i')]);
      expect(proof.contexts, hasLength(LearningStatePolicy.maxContexts));
      expect(proof.recent, hasLength(LearningStatePolicy.recentWindow));
      expect(proof.productionSuccesses, 30);
    });
  });

  group('adaptation strategy', () {
    test('one table: NEW -> KEEP, WEAK -> SIMPLIFY, IMPROVING -> KEEP, '
        'CONSOLIDATED -> STRETCH', () {
      expect(LearningState.newConcept.strategy, AdaptationStrategy.keep);
      expect(LearningState.weak.strategy, AdaptationStrategy.simplify);
      expect(LearningState.improving.strategy, AdaptationStrategy.keep);
      expect(LearningState.consolidated.strategy, AdaptationStrategy.stretch);
    });

    test('the strategy of a concept follows its own state', () {
      final weak = GrammarTopicProgress(
        topic: GrammarTopic.pronouns,
        errorCount: 2,
        exposureCount: 2,
      );
      final improving = GrammarTopicProgress(
        topic: GrammarTopic.passatoProssimo,
        errorCount: 1,
        proof: _proof([ok('a'), ok('b')]),
      );
      final consolidated = GrammarTopicProgress(
        topic: GrammarTopic.articles,
        proof: _proof([ok('a'), ok('b'), ok('c')]),
      );
      final fresh = GrammarTopicProgress(topic: GrammarTopic.wordOrder);
      expect(weak.learningState.strategy, AdaptationStrategy.simplify);
      expect(improving.learningState.strategy, AdaptationStrategy.keep);
      expect(consolidated.learningState.strategy, AdaptationStrategy.stretch);
      expect(fresh.learningState, LearningState.newConcept);
      expect(fresh.learningState.strategy, AdaptationStrategy.keep);
    });

    test('a word is a concept too', () {
      final at = DateTime.utc(2026, 10, 1);
      final word = UserVocabulary.of(word: 'conto', at: at);
      expect(word.learningState, LearningState.weak);
      final practiced = word
          .practice(
            at: at,
            success: true,
            evidenceType: _production,
            context: 'a',
          )
          .practice(
            at: at,
            success: true,
            evidenceType: _production,
            context: 'b',
          )
          .practice(
            at: at,
            success: true,
            evidenceType: _production,
            context: 'b',
          );
      expect(practiced.learningState, LearningState.consolidated);
      final picked = word.practice(
        at: at,
        success: true,
        evidenceType: _recognition,
      );
      expect(picked.learningState, LearningState.weak);
    });
  });

  group('persistence of the ledger', () {
    test('it round-trips', () {
      final proof = _proof([
        ko('a'),
        ok('a'),
        ok('b'),
        pick(true),
        pick(false),
      ]);
      expect(PracticeProof.fromJson(proof.toJson()), proof);
    });

    test('anything malformed reads as empty or is dropped', () {
      expect(PracticeProof.fromJson(null), PracticeProof.empty);
      expect(PracticeProof.fromJson('x'), PracticeProof.empty);
      final proof = PracticeProof.fromJson({
        'productionSuccesses': -4,
        'productionFailures': 'many',
        'recognitionSuccesses': 2,
        'recent': [true, 'x', false, null],
        'contexts': ['a', 3, 'a', 'b'],
      });
      expect(proof.productionSuccesses, 0);
      expect(proof.productionFailures, 0);
      expect(proof.recognitionSuccesses, 2);
      expect(proof.recent, [true, false]);
      expect(proof.contexts, ['a', 'b']);
    });
  });
}
