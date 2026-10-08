# Parla con me! — Architecture (PHASE 0)

## Purpose
An AI-powered Italian tutor that adapts to the learner's mistakes, vocabulary and progress. PHASE 0 delivers only the foundation: structure, navigation, theme, and the abstraction boundaries. No product feature is implemented.

MVP constraints: Android only, Flutter/Dart, no login/account, data stored on device, Gemini as AI provider, no backend.

## Layers
```
Presentation  ->  Domain  ->  Data
```
Cross-cutting `services/` (AI, storage, later audio/speech) sit beside features and are consumed through interfaces. Dependencies point inward: UI never touches Gemini or the storage technology directly.

## Folder structure
```
lib/
  app/        App widget, router, theme, build-time config, DI providers
  core/       Result type, failures, constants (no Flutter UI deps)
  features/   One folder per product area; each owns its presentation/domain/data
    onboarding/  home/  conversation/  learning/  vocabulary/  progress/  profile/
  services/
    ai/       AIService (interface) + GeminiAIService
    storage/  LocalStorage (interface) + SharedPreferencesLocalStorage
  shared/     Widgets reused across features
test/         Mirrors lib/; test/support has fakes
```
Folders are created only when they hold code. `audio/`, `speech/`, `shared/models/`, etc. appear in the phase that needs them. Within a feature, `domain/` and `data/` are added when the feature gets them (today `learning` has `domain`; `profile` has `domain`, `data` and `presentation`; `onboarding` only presentation and writes through the profile).

## State management: Riverpod (`flutter_riverpod`)
- Compile-safe dependency injection and state in one tool; trivial to override in tests.
- Cross-cutting services are exposed in `app/providers.dart`. Feature state lives in the feature's own providers (e.g. `onboarding_controller.dart`). No global app-state blob.

## Navigation: `go_router`
`/onboarding` on first launch, then a `StatefulShellRoute` with bottom navigation: Home (`/home`), Parla (`/home/conversation`), Impara, Parole, Percorso, Profilo (each branch keeps its own stack). A redirect driven by `UserLearningProfile.onboardingCompleted` sends users to the right place. Labels are short so six destinations fit narrow phones. Areas without a feature yet show an honest "Prossimamente" view.

## PHASE 1 — Onboarding, Home, Profile
- **Domain** (`features/profile/domain`): `UserLearningProfile` (`level`, `primaryGoal`, `learningFocus`, `onboardingCompleted`) with enums `ItalianLevel` (includes `notSure`, a real stored answer, never an invented level), `LearningGoal`, `LearningFocus`; and the `UserLearningProfileRepository` interface. These are *declared preferences*, distinct from the Learning Engine's `LearnerLearningSummary` (what the app infers from behavior).
- **Data**: `LocalUserLearningProfileRepository` stores one versioned JSON document under `user_learning_profile` via `LocalStorage`. Enums are saved by name; unknown/corrupt values read back as unset.
- **State**: `userLearningProfileProvider` (saved profile, preloaded in `main()`); `save()` persists first and only then publishes state. `onboardingControllerProvider` (auto-dispose) holds the in-progress draft/step and writes the profile on finish. The router listens to the profile.
- **UI copy** (Italian labels) lives in `profile_labels.dart`, not in the domain. Reusable pieces: `SelectableOptionTile`, `ContentWidth`, `FadeSlideIn`; new tokens `AppSizes`, `AppMotion`.
- **Profile editing**: each preference opens a bottom sheet and saves immediately (single selection; the field can become a set later without breaking stored data).
- Home shows only saved preferences and an empty-state message; no learning statistics exist or are invented. "Ripassa" currently routes to Learning (no review area yet).
- Previous key `onboarding_completed` is no longer read: a Phase 0 install without a stored profile sees onboarding once.

## Local persistence
`LocalStorage` is a small async key-value interface returning `Result`. The implementation uses `shared_preferences` (`SharedPreferencesAsync`), which is simple and reliable for flags/settings. Repositories own serialization, so domain models never depend on storage technology. When learning data needs queries/relations (vocabulary, mistakes, review scheduling), introduce a database behind a new repository/interface (e.g. Drift/SQLite) — domain code is unaffected. The choice of that database is deliberately deferred.

## AI abstraction
`AIService.sendConversation(AIRequest) -> Result<AIResponse>` uses provider-neutral types: `AIRequest` (history as `AIMessage`s + the app-built `systemInstruction`) and `AIResponse` (`message` + `List<Correction>`). `Correction` (`original`, `corrected`, `explanation`, `naturalAlternative`, `category`) lives in `shared/models`. Implementations never throw: failures are `AIFailure` with a `kind` (`notConfigured`, `network`, `rateLimited`, `blocked`, `invalidResponse`, `unknown`); the human-readable `message` is for logs only. Adding another provider = another `AIService` implementation and a changed provider binding.

## Learning Engine boundary
```
Gemini -> Correction -> LearningEngine -> LearningRepository -> local persistence
```
Gemini produces text and structured corrections; it never touches storage or decides how statistics accumulate. The engine interprets; the repository stores; neither knows the other's details.

## PHASE 3A — Learning domain & memory
`features/learning` holds what the app *learns about the learner* (`LearnerLearningSummary`), kept separate from what the learner *declared* in onboarding (`UserLearningProfile`).

- **Models** (`domain/`): `LearningError` (a mistake pattern with `frequency`, `firstSeenAt`, `lastSeenAt`, `confidence`, optional `grammarTopic`), `GrammarTopic` + `GrammarTopicProgress` (exposure/error/success counts), `UserVocabulary`, `LearningSignal` (type, source, confidence, metadata) and the aggregate `LearnerLearningSummary` (`totalErrors`, `recurringErrors`, `grammarTopics`, `vocabularyItems`, `lastUpdatedAt`). Domain models are immutable and know nothing about storage.
- **`LearningRepository`** (interface): `getLearningSummary`, `recordError`, `recordVocabulary`, `recordGrammarTopicExposure`, `recordSuccessfulGrammarUse`, `clearLearningData`. It stores and merges; it contains no pedagogy.
- **`LocalLearningRepository`**: one versioned JSON document under `learning_memory` in `LocalStorage` (`{"version":1,"errors":[],"grammarTopics":[],"vocabulary":[]}`). Defensive reads like conversations: nothing stored, a corrupt document, or an unknown version-less document reads as empty; corrupt entries are skipped; out-of-range numbers are dropped. A document with a *newer* `version` is never read or overwritten (every operation returns a `StorageFailure`) so an older app cannot destroy newer data. Mutations are serialized through a queue so concurrent read-modify-write cycles don't lose updates. Conversations are untouched, and `clearLearningData` only removes the memory.
- **`DefaultLearningEngine`** (replaces the inert Phase 2 engine): `Correction -> [LearningSignal] -> repository calls`. `interpret` (pure) creates signals; `apply` writes one. An explicit AI correction becomes a `grammarError`, `vocabularyIssue` or `correction` signal (confidence 0.9) plus one `topicExposure` signal per inferred topic. A vocabulary issue also records the correct word as relevant vocabulary. PHASE 3A used only the AI's structured corrections; PHASE 3B adds conservative detection of correct use (below). It never analyzes language in general, calls an AI, or personalizes anything.
- **De-duplication** (`ErrorPattern`): identity is the normalized *smallest differing span* of `original -> corrected`, plus one neighbouring word when the differing words are short (≤4 letters: `ho/sono`, `la/il`, `in/al`). So `"Ieri ho andato al supermercato."` and `"ho andato"` are the same key, `ho andato -> sono andato`, and a repeat raises `frequency` and `lastSeenAt` instead of adding a record. Case and edge punctuation are ignored; accents are kept (`perche -> perché`). The AI's category is deliberately *not* part of the key because the model can label the same pair differently between runs, which would split the counts. Identical/empty pairs are not mistakes and are ignored. Limitations: different surface forms of one mistake (`ho andato` vs `abbiamo andato`) are different patterns, and a whole-sentence rewrite produces a long pattern that rarely repeats exactly.
- **Grammar topic inference** (`grammar_topic_inference.dart`): a tiny deterministic rule set: avere + motion participle replaced by essere (`essereVsAvere` + `passatoProssimo`, confidence 0.8); only articles changed (`articles`, 0.6); only prepositions changed (`prepositions`, 0.6). No rule means `grammarTopic = null`: no topic beats a wrong topic.
- **Confidence semantics.** `LearningError.confidence` / `LearningSignal.confidence` = certainty of the *evidence* (0.9 explicit AI correction; 0.8 / 0.6 rule inference). `GrammarTopicProgress.confidence` and `UserVocabulary.confidence` = approximate *mastery*, derived as successful uses / exposures (not stored, so the estimator can change without migrating data; 8 exposures with 4 successes = 0.5).
- **Conversation integration.** After a reply is shown and saved, `ConversationController` calls `LearningEngine.analyze` in the background. A failed `Result` or an exception is swallowed (only the failure *type* is logged, in debug builds); the conversation is already updated and keeps working.
- **Not in this phase:** any UI for the memory, sending memory to Gemini (PHASE 3C), spaced review, a database.

Signals are the engine's working language and are deliberately **not persisted**; what is stored is the bounded, accumulated memory.

## PHASE 3B — Learning evolution & signals
The memory now records recovery, not only mistakes. Still one AI response per message, no extra AI calls, no persistence change: `learning_memory` stays `version: 1` and a PHASE 3A document is read as is (3B added no stored field).

- **Three different things, never confused.** *Error*: the learner produced something wrong (reported by the AI): topic `exposure +1`, `error +1`. *Exposure*: the learner touched a relevant topic or word. *Successful use*: the learner used correctly something they had been corrected on: `exposure +1`, `success +1`. So `exposure >= errors + successes`, and counts are per message, never per occurrence.
- **Signals** (small, internal, not persisted): `grammarError`, `vocabularyIssue`, `correction`, `topicExposure`, `successfulGrammarUse`, `successfulVocabularyUse` (replaces the unused `vocabularyLearned`).
- **How a turn is processed** (`DefaultLearningEngine.analyze`): read the memory as it was *before* the turn → `interpret` the AI corrections into error signals → `interpretSuccesses` compares the learner's message with that memory → `apply` every signal. If the memory cannot be read, mistakes are still recorded and a failure is returned (no success detection without something to compare to). `LearnerLearningSummary` now exposes every error (`errors`), not just the recurring ones, for this comparison.
- **Grammar success detection** (`success_detection.dart`), deliberately conservative. A topic is credited from a *known mistake that has an inferred topic* only when: (1) the message contains the mistake's **corrected wording** as consecutive words (`sono andato` after `ho andato -> sono andato`), or, for the essere/avere rule only, the same verb with any essere form/gender/number (`siamo andati`, `è andata`; confidence 0.7 literal, 0.6 structural); (2) the message does **not** contain the mistaken wording (`ho andato`, `abbiamo andato`); (3) this turn's AI response did not correct that mistake nor report any mistake in that topic. At most one success per topic per message. Nothing is credited for correct Italian in general (`Oggi mangio una pizza.` proves nothing), for a topic with no earlier mistake, or for a mistake without an inferred topic. Limitations: other verbs/tenses of the same rule (`sono venuto` after `ho andato`), inflected articles/prepositions and meaning are not understood; a repeated mistake that the AI did not correct (Correggimi off) is not counted as an error either, because errors only come from AI corrections.
- **Vocabulary.** A `vocabulary` correction records only the *differing corrected words* (`reserva -> prenotazione` records `prenotazione`), without a leading article. Empty results, words shorter than 3 letters and phrases of more than 3 words are skipped (the error is still recorded). Identical pairs create nothing. Identity is `language:word` case-insensitive, so repeats merge into one item (`exposureCount`, `lastSeenAt`). A success is counted only for words **already in the memory**, found as whole words (case-insensitive, consecutive for phrases) in the learner's message, once per message and never for a word corrected in that same message. Inflected forms (`prenotazioni`) are not matched.
- **Recurrence and relevance.** `recurringErrors` = frequency ≥ 2 (one sighting may be a slip, two is a pattern); `errors` lists all. Priorities are derived, never stored: `LearningError.priority(now) = frequency × confidence × recency` and `GrammarTopicProgress.priority(now) = errors × (1 − mastery) × recency`, where recency halves every 14 days (`relevance.dart`). `LearnerLearningSummary.prioritizedErrors(now)` / `prioritizedTopics(now)` order them (topics without errors are excluded). Mastery stays `successes / exposures`, clamped to 0..1: one error followed by two correct uses is 2/3.
- **Not in this phase (FUTURE):** sending any of this to Gemini (PHASE 3C), UI, review/exercises, an advanced mastery model, linguistic analysis, counting a mistake the AI did not report.

## PHASE 3C — Personalized AI & learning context
```
LearnerLearningSummary -> buildLearningContext -> LearningContext -> buildTeacherInstruction -> AIRequest -> AIService -> Gemini
```
The memory closes the loop: what was learned in earlier turns shapes the next one, and the new reply feeds the memory again. Gemini never touches the repository, storage, saved conversations or the internal models; it only receives the instruction text the app builds.

- **Where each piece lives.** `LearningContext` (`learning/domain/learning_context.dart`) is a small *view* of the memory, not a copy. `buildLearningContext` (`learning_context_builder.dart`) is pure and selects it from a summary. `LearningEngine.learningContext()` exposes it (one memory read). `ConversationController` asks for it once per request, builds the instruction with `buildTeacherInstruction(..., learningContext:)` and sends it. **`AIService` and `GeminiAIService` did not change**: since PHASE 2 the app owns the teacher's behavior and the provider only transports the instruction, so personalization needed no new contract and no provider code. Another provider gets it for free.
- **Selection** reuses the PHASE 3B priorities (`prioritizedTopics/Errors`) and adds `UserVocabulary.priority` / `prioritizedVocabulary` in the same style; there is no second scoring system. Limits: **3 priority topics, 3 recurring errors, 5 words, 2 positive signals**.
  - *Priority topics*: at least one error, not yet clearly improving, priority ≥ 0.1 (a lone mistake fades after about six weeks). A topic with no errors has no evidence and is never sent.
  - *Recurring errors*: frequency ≥ 2 only, still relevant, and not in an area that is already improving. Sent as `"incorrect" instead of "correct"`.
  - *Vocabulary*: Italian words not yet known (mastery < 0.7), most relevant first, de-duplicated.
  - *Positive signals*: problem topics with clear improvement (≥ 3 successes and mastery ≥ 0.6), strongest first. They tell the AI not to simplify or over-correct there.
- **What is sent, and what is not.** Sent: short pedagogical phrases (the areas to reinforce in plain words, the mistaken and correct forms, the words), plus usage rules for the AI. **Not sent**: ids, timestamps, frequencies, counts, confidences, the memory document or any JSON, storage details, saved conversations, personal or device data, the API key. The conversation history window (24 messages) is unchanged and is *not* replaced by memory. Data minimization matters because, unlike the memory itself, this slice leaves the device inside the request.
- **Learner text is sanitized** before it can enter the instruction (it is the learner's own writing, passed through the AI's correction): only short fragments (≤ 40 characters) of letters, spaces, apostrophes and hyphens; digits, quotes, markup and any control character (such as line breaks) are dropped. Residual limit: plain words cannot be told apart from a genuine mistake, so a learner could shape their own tutor with a short phrase; that only affects their own local session.
- **The prompt** (`teacher_prompt.dart`) gains one `LEARNING CONTEXT` section, only when the context is non-empty: use it to shape the conversation, create chances to practice only when the conversation allows it, never force a topic or repeat an exercise, **never mention the guidance, the history, progress, statistics or that it remembers anything** (with examples of what not to say), do not change when it corrects or praises, put natural communication first, and raise the level gradually where the learner is improving. Correggimi is independent: memory never turns it on and Correggimi OFF does not add corrections.
- **Empty memory.** `LearningContext.empty` adds nothing: the instruction, and therefore the request, is byte-for-byte what it was before personalization (a test compares them). No placeholder text.
- **Memory unreadable** (failed result, exception, or a newer unreadable document): the request goes with the empty context, the chat works as usual and the user sees nothing; only the failure type is logged in debug builds.
- **Cost.** One memory read per request to build the context (plus the existing one in the learning analysis after the reply); no extra network calls; the section adds about 1.5 KB of instruction at most.
- **Not done (FUTURE):** any visible progress, exercises, vector/semantic search, per-item controls over what is shared.

## PHASE 2 — AI conversation (Parla)
```
ConversationScreen -> ConversationController -> AIService -> GeminiAIService -> Gemini
                              |                      
                              +-> ConversationRepository -> LocalStorage
                              +-> LearningEngine.analyze
```
- **Who owns what.** The controller owns state, history, persistence, and the teacher's behavior; Gemini is only a text-in/reply-out capability. The behavior lives in one place, `conversation/domain/teacher_prompt.dart`: a fixed `teacherSystemPrompt` (personality, Italian-first with Spanish only for hard explanations, short replies, one follow-up question) plus a parameterized section built by `buildTeacherInstruction(profile, correctionMode)` (level guidance A1–B2/unknown, goal, focus, and the "Correggimi" block). Only profile fields that exist are included; nothing is invented.
- **Domain** (`conversation/domain`): `ConversationMessage` (`id`, `role`, `content`, `createdAt`, `corrections`), `Conversation` (`id`, `createdAt`, `updatedAt`, `messages`), `ConversationRepository`. No provider types.
- **Controller states**: `loading` (reading storage) → `idle` → `sending` → `idle | error`. Sends are ignored while `sending`; "new conversation" is disabled while `sending` or when the current one is empty. A failed turn keeps the user's message and offers retry (re-asks without duplicating the message). The last 24 messages are sent as context, always starting with a user turn.
- **Correggimi** is an in-session toggle that only changes the instruction; corrections are always allowed in normal mode when useful.
- **Gemini** (`services/ai`): `GeminiAIService` builds the REST `generateContent` request (`http` package, injected client, 30 s timeout), sends the key in the `x-goog-api-key` header (never in the URL), and appends the provider-side output contract (JSON `{message, corrections[]}`) to the app's instruction. `responseMimeType: application/json` is requested, but the format is described in the prompt rather than enforced with `responseSchema`, and the output is treated as untrusted by `gemini_response_parser.dart`: code fences stripped; invalid corrections dropped; unknown categories become `other`; plain text is accepted as a message; JSON-looking but broken/truncated output is an `invalidResponse` (the learner never sees raw braces); blocked prompts map to `blocked`; thought parts are ignored. HTTP 401/403 and `API_KEY_INVALID` → `notConfigured`, 429 → `rateLimited`, 5xx/timeouts/socket errors → `network`. It never stores conversations, touches state or reads the profile.
- **Persistence** (`LocalConversationRepository`): all conversations in one versioned JSON document (`conversations` key, `v: 1`) via `LocalStorage`, most recent first. Reads are defensive: a corrupt document reads as empty and corrupt conversations/messages are skipped. The whole document is rewritten on each save, which is fine for MVP volume; swap in a database-backed `ConversationRepository` (e.g. Drift) later without UI changes. A failed save never interrupts the chat. The user message is saved before the AI call, so it survives a crash. On start, the most recent non-empty conversation is restored; empty conversations are never written.
- **UI**: reversed list (newest anchored at the bottom), thinking bubble with animated dots, correction cards under the assistant bubble, friendly Italian error messages per failure kind (no HTTP codes, stack traces, keys or SDK details), "Correggimi" chip, suggestion chips on an empty conversation, "Nuova conversazione" in the app bar.
- **Privacy.** Conversations are stored only on the device, but each message (with the recent history and the learner's level/goal/focus) is sent to Gemini to generate the reply. No name, email, phone, location or analytics is collected or sent.
- **Not in this phase**: voice, advanced memory (semantic/embeddings/RAG), real Learning Engine, conversation list screen, structured-output schema enforcement.

## PHASE 4A — Learning experience & progress
```
LocalLearningRepository -> LearningEngine.overview() -> LearningOverview -> learningOverviewProvider -> Impara / Parole / Percorso / Home
```
The intelligence that already existed is now visible. **The domain stays the single source of truth and the screens calculate nothing**: no widget reads storage, ranks anything, interprets an error or re-implements a rule. There is no Review Engine, no exercises and no gamification (no XP, streaks, levels or invented percentages).

- **One definition of "what matters now".** The selection rules that used to live inside `buildLearningContext` (priority topics, improving topics, recurring errors, vocabulary still to consolidate) were extracted, unchanged, into public selectors in `learning_context_builder.dart`. The AI context and the learner-facing overview both use them, so what the teacher is told and what the learner sees can never disagree, and there is no second scoring system.
- **`LearningOverview`** (`learning/domain/learning_overview.dart`, pure Dart, display data only) is built by `buildLearningOverview` from a `LearnerLearningSummary`. It holds `TopicView` (topic, standing improving/toReinforce, real counts "correct out of appearances", related mistakes, related topics), `ErrorView`, and `VocabularyView`, in lists with fixed limits (5 topics, 5 recurring errors, 3 related errors per topic, 50 words per section). It exposes no ids, dates or internal scores. There is deliberately no single "total progress" number.
- **State and reactivity (Riverpod).** `LearningEngine.overview()` makes one memory read. `learningOverviewProvider` (a `FutureProvider`) is read by all four screens and keeps the previous value while it refreshes, so nothing flickers. The repository has no change stream, so `learningRevisionProvider` is a tiny counter that the learning engine bumps whenever it really changes the memory (see *Phase 10B.1*); the overview watches it and refreshes by itself, with no restart. It carries no data, so the repository remains the only source (no cache, no second store). Automatic retry is switched off on this provider: Riverpod 3 retries failed providers by default, which would keep the screens on a spinner instead of the friendly error; "Riprova" is the user's choice.
- **Screens.** All copy is Italian and non-technical.
  - *Percorso*: "Stai migliorando", "Da rinforzare", "Errori ricorrenti" and a three-word preview of "Parole". A topic shows a bar only when there is real evidence, always with its meaning ("Corretto 4 volte su 8"); a topic with no correct use yet says "Ancora da consolidare".
  - *Impara*: the entry point to what to work on: the top priority as a warm focus card, the ranked priorities, and how to work on them (by talking; there are no exercises).
  - *Parole*: "Parole da consolidare" and "Parole che stai usando", split by the same mastery threshold the AI uses to stop reinforcing a word. Nothing is ever called "learned", because the conservative detection cannot prove that.
  - *Home*: the invitation to the first conversation while the memory is empty, then the current focus and what is improving; nothing while loading or if the memory cannot be read. "Parliamo" stays the main call to action.
  - A *topic detail* sheet (reusable from Percorso and Impara) shows only what the memory knows: connected topics, the mistakes behind it, the evidence of progress. It adds no grammar explanation and no exercise, so navigation did not change.
- **Empty, partial and failure states.** Empty memory is a friendly start (no zeros, no placeholder); only errors, only words or only progress each render just their own section; an unreadable memory shows a calm error with a retry (Home simply stays quiet); loading shows a spinner and never a false "empty".
- **Profile vs learning stay separate.** The declared profile (level, goal, focus) and the learned memory are different stores and different parts of the screen; changing the profile does not touch the memory.
- **No persistence change** (`learning_memory` stays version 1) and no change to Gemini or `AIService`.

## PHASE 4B — Review Engine
```
learning_memory -> ReviewEngine -> review_memory -> (future) review consumers
```
- **Two stores, two questions.** `learning_memory` (unchanged, still `version: 1`) says *what* the learner struggles with; `review_memory` (new, `{"version":1,"items":[...]}`, key `review_memory`) only says *when* each thing is due again. A `ReviewItem` holds scheduling state and a reference (`type` + `sourceId`) to the learning entity, never a copy of it. Stable ids: `error:<LearningError.id>`, `grammar:<topic name>`, `vocabulary:<UserVocabulary.id>`.
- **Supported types:** `error`, `grammar`, `vocabulary` (`ReviewItemType`; new kinds are added there). Lifecycle `fresh -> learning -> review -> mastered`.
- **Candidates vs scheduling.** Candidates and priority are read live from learning memory using its existing selection rules and `priority(now)` (recurring errors, topics to reinforce, vocabulary of the learner's `learningLanguage`); priority is never stored. Scheduling is stored and changes only through review results (or a repeated mistake reopening an error item); synchronization creates missing items and never resets an existing schedule.
- **Policy (`ReviewPolicy`):** success intervals 1, 3, 7, 14, then 30 days; a failure resets the progression, keeps the counters and retries after 10 minutes (so a session cannot loop on it); `review` after 2 correct in a row; `mastered` after 5 correct in a row with a 30-day interval. Deterministic: no AI, no randomness, time is always passed in.
- **Queue:** due items (`nextReviewAt <= now`), ordered by priority, then older `nextReviewAt`, then id, limited to N. Persistence is defensive like the other stores; a failing save never fails the call. No UI consumes the engine yet (`reviewEngineProvider`).

## PHASE 4C.1 — Exercise domain & generator
```
ReviewEngine -> ReviewItem -> ExerciseGenerator -> Exercise
```
The review engine decides *what/when*; the generator decides *how*. `DefaultExerciseGenerator(learningLanguage)` is a pure function of a `ReviewItem` and the `LearnerLearningSummary` it points to: no storage, AI, network, clock or randomness, and exercises are ephemeral (no new persistence key; `learning_memory` and `review_memory` untouched). It returns `Result<Exercise>`; when the data is not enough it returns `ExerciseUnavailableFailure(reason)` instead of inventing content.
- `error` -> `errorCorrection`: `LearningError.original` -> `corrected` (+ explanation).
- `grammar` -> `grammarChoice`: options are the learner's own forms (`corrected`/`original`) from that topic's `LearningError`s, at most 4, alphabetical; the correct one comes from the most frequent. A topic without errors of its own is unavailable (`GrammarTopicProgress` holds only counters).
- `vocabulary` -> `vocabularyContext`: a cloze from a recorded correction containing the word plus at least one more word. Without such a correction it is unavailable (`UserVocabulary` stores no example sentence and `meaning` is not populated yet). Only vocabulary of the learner's `learningLanguage` is used.
`Exercise` carries no UI copy: `prompt` is the wrong text, the topic key or the blanked phrase depending on `type`; answers are compared deterministically by the future session.

## PHASE 4C.2 — Review session controller
```
ReviewEngine = what/when   ExerciseGenerator = how   ReviewSessionController = orchestration
```
`reviewSessionControllerProvider` (an auto-disposed Riverpod `Notifier`, no UI) runs one session: it reads the review queue **once**, takes in queue order the first `reviewSessionSize` (5) candidates the generator can build an exercise for, and works on that snapshot. A candidate whose exercise is unavailable is *skipped*: counted in `summary.skipped`, never recorded as success or failure, so scheduling is untouched (at most `reviewSessionScanLimit` candidates are examined, each once).
- **State** (`ReviewSessionState`, no UI text): `idle -> loading -> answering -> submitting -> feedback -> answering ... -> completed`, or `error` (queue, learning memory or `recordReviewResult` failed; never reported as a success). It exposes the current exercise, position/total, the last `AnswerOutcome` and session-local counts (correct, incorrect, skipped; nothing persisted, no scores).
- **Operations** are ignored (deterministically) outside their state: `submitAnswer` only while `answering` (it moves to `submitting` synchronously, so a second call cannot record twice), `continueSession` only in `feedback`, `start` only from idle/completed/error. A blank answer, or a choice that is not an option, is not an answer.
- **Evaluation** (`AnswerEvaluator`): multiple choice must equal the correct option exactly; typed answers (error correction, vocabulary) are compared after `normalizeAnswer` (trim, collapse whitespace, lowercase; accents and punctuation kept, no fuzzy matching).
- `recordReviewResult(success|failure)` is called right after evaluation and is the only thing that persists anything; the controller holds no scheduling logic and the clock is injectable (`reviewSessionClockProvider`).

## PHASE 4C.3 — Review experience UI
"Ripassa" is `ReviewScreen` (`/review`, a full-screen route above the shell, opened with `push` from the Home quick action; back pops it). It only renders `ReviewSessionState` and forwards `start`, `submitAnswer` and `continueSession` to `reviewSessionControllerProvider`; it never evaluates answers, schedules or reads storage. The session starts once when the screen opens and is disposed with it (leaving mid-session records nothing). Rendering by `Exercise.type`: typed input for error correction and vocabulary, single-choice options for grammar (the topic key is shown as its label); feedback comes only from `AnswerOutcome`, and correct/incorrect is conveyed by icon and text, not color alone.

## PHASE 5.1 — Multilingual architecture
Three different languages, never assumed equal:
- **UI language**: the language of the interface text (today fixed Italian). Not part of the learner profile.
- **Support language** (`UserLearningProfile.supportLanguage`): the one the learner already understands; the teacher uses it only for hard explanations. It was called `interfaceLanguage` before this phase (same meaning); the old stored key is still read and the next save writes `supportLanguage` (profile document stays `v: 2`).
- **Learning language** (`learningLanguage`): the one being learned.

`LanguagePair(support, learning)` (`profile/domain/language_pair.dart`, exposed as `profile.languagePair`) is the immutable pair; `isSupported` requires the support language to be in `availableSupportLanguages`, the learning language in `supportedLearningLanguages`, and the two to differ. Being in `AppLanguage` means only "known by name": a language becomes selectable only when it is added to those lists, and a stored language that is not usable falls back to the default when the profile is read.

**Language rules boundary.** Memory, priorities, the review engine, the session and the exercise generator are generic (they only carry a language code, taken from the profile). What depends on a language's grammar sits behind `LanguageLearningRules` (`learning/domain/language_learning_rules.dart`): grammar-topic inference, correct-use detection, what counts as an article, and how topics are named for the AI. `DefaultLearningEngine` is handed the rules of the learner's language (`learningRulesProvider`) and never branches on a language; `learningRulesFor(language)` returns `null` for a language the app cannot teach, which is what makes a language "supported". `ItalianLearningRules` is the only implementation; its rule sets are `grammar_topic_inference.dart` and `success_detection.dart` (Italian-only).

**Current supported pairs: Spanish -> Italian and Spanish -> English** (see PHASE 5.2). Still Italian-specific by design: the Italian rule files above, the Italian `GrammarTopic` values and the UI copy, and the legacy default `'it'` of `UserVocabulary.of`.

## PHASE 5.2 — English as a second learning language
```
Support languages:  Spanish
Learning languages: Italian, English      (supportedLearningLanguages, in that order)
```
`AppLanguage.english` (`en`) is in `supportedLearningLanguages` because `learningRulesFor(english)` returns `EnglishLearningRules`; it is NOT an available support language and the UI stays Italian (the UI copy that named the language was made language-neutral). Adding a language is: its rules + one entry in the capability list.
- **Rules** (`english_learning_rules.dart`): conservative, deterministic inference of third-person singular, present continuous, past simple / present perfect, the verb *to be*, articles (`a`, `an`, `the`), prepositions swaps and word order; no topic when there is no clear evidence. Correct-use detection is literal and credits the topic recorded with the mistake. `ErrorPattern.precedingToken` (the word before the differing span) gives rules their context, e.g. the subject of a verb. Topic names for the AI come from the rules; the UI names are in `learning_labels.dart`.
- **`GrammarTopic`** stays one enum. Topics shared by name across languages (`articles`, `prepositions`, `wordOrder`) mean the same concept; English adds `toBe`, `presentContinuous`, `pastSimple`, `presentPerfect`, `thirdPersonSingular`. Identity is scoped by language, not by the enum.
- **One memory, scoped by language.** `learning_memory` stays `version: 1`; mistakes, grammar progress and vocabulary now carry a `language` (a missing field means the legacy language, Italian, `legacyLanguageCode`). Ids are `scopedId(language, key)`: unchanged for Italian (so every stored id and review item stays valid) and `<code>:<key>` for any other language, so the same words or topic in two languages never collide. The engine, the review engine, the exercise generator and the screens only see the current language (`LearnerLearningSummary.forLanguage`); switching language never deletes or mixes the other's data. Grammar review ids: `grammar:articles` (Italian, unchanged) and `grammar:en:articles` (English). `review_memory` is unchanged (v1).
- **Profile** needs no new version: it stores language names. Any stored learning language that is not supported falls back to the default.

## PHASE 6.1 — Interface localization
The interface is translated with Flutter's `gen-l10n`: messages live in `lib/l10n/app_<code>.arb` (`en` is the template; `es`, `it` complete) and widgets read them with `context.l10n`. A test checks that every language has the same keys, non-empty text and the same placeholders. Enum labels (levels, goals, focus areas, grammar topics) take the localizations (`level.label(l)`), and language names are always shown in their own language ("Español", "English", "Italiano").
- **Interface languages** (`availableUiLanguages`): Spanish, English, Italian. A language can be the learner's *support* language only if the interface exists in it (`availableSupportLanguages` is the same list). Adding an interface language = its `.arb` + an entry in that list; adding one to learn is still a separate matter (learning rules).
- **Which language the app shows**: `UserLearningProfile.uiLanguage` is an optional override; `null` means "the support language" (`effectiveUiLanguage`). The profile screen offers any interface language; choosing the support language clears the override, choosing another (for example the language being learned, for immersion) stores it. Stored in the same `v2` profile document (`uiLanguage`, absent = follow support).
- **Onboarding** starts in the device language when the app has it (else English), preselects it as the support language and the first other language to learn, and the interface switches the moment the learner picks theirs (`onboardingUiLanguageProvider`). A language is never learned through itself: picking a support language equal to the language to learn moves the latter aside, and the learning list leaves out the support language.
- Not part of this phase: more interface or learning languages (French, Portuguese, German, Spanish, Mandarin come next, each with its translation / rules).

## PHASE 6.2 — French as a learning language
```
Support / interface languages: Spanish, English, Italian
Learning languages:            Italian, English, French
```
`AppLanguage.french` (`fr`) is a supported *learning* language because `learningRulesFor(french)` returns `FrenchLearningRules`; it is not an interface or support language (there is no French translation yet). Rules (`french_learning_rules.dart`), conservative like the others: être vs avoir as the auxiliary of the passé composé (verbs that take either are left out), plural marking after a plural determiner, a verb's ending after its subject pronoun, articles, preposition swaps and word order. Correct-use detection is the shared literal one (`detectLiteralGrammarSuccesses`, also used by English). New topics: `etreVsAvoir`, `passeCompose`; the others are shared by name and kept apart per language by the memory's language scope (French ids are `fr:...`, review ids `grammar:fr:...`). No storage change.

## PHASE 6.3 — Portuguese as a learning language
```
Support / interface languages: Spanish, English, Italian
Learning languages:            Italian, English, French, Portuguese
```
`AppLanguage.portuguese` (`pt`) is a supported learning language through `PortugueseLearningRules` (not an interface or support language yet). Conservative rules: *ser* vs *estar* (one verb replaced by the other), preposition + article that should be a contraction (*em o* -> *no*), plural marking after a plural determiner, a verb's ending after its subject pronoun, articles (the word *a*, article and preposition at once, is not inferred when only added or dropped), preposition swaps and word order. New topic: `serVsEstar`. Memory ids are scoped `pt:...`, review ids `grammar:pt:...`. The helpers the English, French and Portuguese rules share (function-word swaps, word order, same-stem endings) live in `rule_helpers.dart`; correct-use detection is the shared literal one.

## PHASE 6.4 — German as a learning language
```
Support / interface languages: Spanish, English, Italian
Learning languages:            Italian, English, French, Portuguese, German
```
`AppLanguage.german` (`de`) is a supported learning language through `GermanLearningRules` (not an interface or support language yet). Conservative rules: *haben* vs *sein* as the Perfekt auxiliary, article forms with case-marking forms (*den, dem, des, einen...*) told apart as `cases`, a verb's ending after its subject pronoun, preposition swaps, and word order (which covers the verb position). New topics: `habenVsSein`, `perfekt`, `cases`. In German the participle sits at the end of the clause, far from the auxiliary, so `ErrorPattern` now also keeps the full normalized tokens of both texts (`fullOriginalTokens`, `fullCorrectedTokens`) as context for rules; they are not part of the pattern's identity or of any stored data. Known limit: capitalization (German nouns) is ignored by the pattern machinery, so a capitalization-only correction is not tracked. Memory ids are scoped `de:...`, review ids `grammar:de:...`.

## PHASE 6.5 — Spanish as a learning language
```
Support / interface languages: Spanish, English, Italian
Learning languages:            Italian, English, French, Portuguese, German, Spanish
```
Spanish was already an interface and support language; it is now also a language to learn (for someone whose support language is English or Italian), through `SpanishLearningRules`. The pair rule keeps a language from being learned through itself, so a Spanish speaker never sees Spanish among the languages to learn. Conservative rules: *ser* vs *estar*, *por* vs *para*, the contractions *al* and *del*, plural marking after a plural determiner, a verb's ending after its subject pronoun, articles, preposition swaps (the personal *a*, which comes and goes, is not inferred) and word order. New topic: `porVsPara`; `serVsEstar` is shared with Portuguese by name and kept apart per language by the memory scope. Memory ids are scoped `es:...`, review ids `grammar:es:...`. `¿` and `¡` are treated as punctuation at the edge of a word (shared tokenizer), which does not change any other language.

## PHASE 6.6 — Mandarin Chinese as a learning language
```
Support / interface languages: Spanish, English, Italian
Learning languages:            Italian, English, French, Portuguese, German, Spanish, Mandarin
```
`AppLanguage.mandarin` (`zh`, shown as 中文) is a supported learning language through `MandarinLearningRules` (simplified characters; not an interface or support language yet).
- **Reading Chinese.** The pattern machinery used to split text on spaces, which Chinese does not use. `ErrorPattern` now reads text per script: every Han character is a token of its own and any other run (Latin, pinyin) stays a word, so "iPhone很好" is *iPhone, 很, 好*; Chinese punctuation is dropped like other punctuation. A mistake is therefore the few characters that changed, written back without spaces (`ErrorPattern.joinTokens`: a space between words, none between Han characters). Text in any other script tokenizes exactly as before.
- **Vocabulary.** A Chinese word is up to four characters, and a character counts double for the minimum length, so a two-character word like 电脑 is tracked.
- **Rules**, conservative like the others: negation 不 vs 没, the particles 的 / 得 / 地, measure words (swapped, or missing after a number or 这/那), the aspect particles 了 / 过 / 着, and word order. Chinese has no articles, conjugation or plural marking, so those topics do not exist for it. New topics: `negation`, `structuralParticles`, `measureWords`, `aspectParticles`.
- **Teaching note.** `LanguageLearningRules.teachingNote` lets a language tell the teacher how it should be taught; Chinese asks for simplified characters with pinyin (tone marks) after the sentence for beginners and new words. Other languages have none.
- Memory ids are scoped `zh:...`, review ids `grammar:zh:...`.

## PHASE 7 — Voice: listening and speaking
**Listening (text to speech).** `SpeechService` (`services/speech`) reads text with the phone's own voices (`flutter_tts`): no network, no key, no cost. `SpeechController` reads one thing at a time and tells each button apart by key, so only the one being read shows "stop". Every teacher message has a listen button, and every correction offers *"Hear how it is said and written correctly"*: **Listen** (the corrected text), **Slowly**, and **Spell it** (`spellOut`: letter by letter, words apart; each Chinese character on its own). The voice is the one of the language being learned (`speechLocaleTag`). If the phone has no voice for it the app says where to install one. Replies are read aloud automatically after a voice message, and for typed messages when the learner turns on *Read replies aloud* (`UserLearningProfile.speakReplies`: a switch in the chat and in Profile).

**Speaking (voice messages).** `VoiceRecorder` (`services/audio`, the `record` package) records up to a minute of 16 kHz mono WAV; the file only exists while recording and is deleted when read. `VoiceInputController` runs one recording (start, finish, cancel; leaving the screen cancels it; the minute limit sends it). The recording goes to the AI **inline with the learner's message** (`AIMessage.audio`), once: Gemini listens to it, and the reply carries `transcript` (what was said, mistakes included), the usual corrections, and, only when a word was clearly mispronounced, a `pronunciation` correction (`original` = how it sounded, `corrected` = the right word, `explanation` = how it should sound). The transcript becomes the text of the learner's message (`ConversationMessage.isVoice`), so history, learning memory, review and exercises treat a spoken sentence exactly like a typed one.
- **Nothing audio is stored**: not in conversations, not in the learning or review memory. A voice message whose reply never came cannot be sent again after the app is closed, and is dropped; while the app stays open a failed one can be retried with the same recording.
- The microphone is only used while a recording is in progress (permission `RECORD_AUDIO`, asked when the learner first records).
- Pronunciation feedback is the model's judgment of the audio, not a phonetic analysis; the instruction asks it not to invent problems or judge accent.

## PHASE 8 — Daily routine
A pure orchestration layer (`lib/features/daily_routine/`): it decides **what to practice today** and records that it was done. It creates no learning, review or conversation logic of its own.

- **Three ordered steps.** *Ripassa* (≤3 real review exercises), *Parla* (a scenario mission), *Consolida* (≤2 real words). Each step is `pending`, `completed` or `unavailable`; an unavailable step (nothing real to practice) is left out and does not count in the progress. Steps cannot be jumped or repeated (`DailyRoutine.completeStepN()` returns `null` when invalid).
- **Planner** (`DailyRoutinePlanner`, pure: it only reads). Step 1 takes the `ReviewEngine` queue in its own order and keeps the first items `ExerciseGenerator` can build an exercise from; step 3 uses `selectVocabularyToReinforce`; step 2 comes from `ScenarioGenerator`. Everything is filtered by the learning language (`LearnerLearningSummary.forLanguage`).
- **Scenario.** `ScenarioGenerator` maps the weakest grammar topics (or, with none, the learner's goals) to a language-neutral `ScenarioSituation`, rotating by day. No extra Gemini call: the mission is an extra instruction in the usual teacher prompt, and the conversation opens with a hidden trigger so the teacher speaks first. Reuses `ConversationController` (`startScenario` / `finishScenario`); the mission can be finished after `minTurns` learner messages.
- **Review reuse.** `ReviewScreen(routine: true)` and `ReviewSessionController.start({size, onlyItems})` run the existing session limited to the routine's items; finishing it completes step 1.
- **Persistence.** `LocalDailyRoutineRepository` (`daily_routine` key, versioned JSON, defensive decoding, last 14 days, serialized writes). Identity = date + learning language (`yyyy-MM-dd|code`); an existing routine is reloaded, never planned again, even if the memory changed.
- **State.** `dailyRoutineProvider` (`AsyncNotifier`: loading / data / error, automatic retry disabled so the error is shown with a button). `completeStep` ignores invalid jumps and double taps. The Home `RoutineCard` shows the real `done/total` and a CTA (*Inizia* / *Continua* / *Completata*).
- **Not included:** XP, streaks, rewards, statistics, notifications, backend.

## PHASE 9B — Personalized learning guidance

```
DailyRoutine → LearningGuidanceResolver → derived personalized CTA → Ripassa / Parla / Consolida
```

- **Derived, not stored.** `LearningGuidanceResolver` (`features/guidance/domain`) is a pure function over the already-made `DailyRoutine` (plus the profile's goals, only to name a goal-based mission). It reads no engine, repository, network or clock, and writes nothing. No guidance storage, cache or repository exists; `learningGuidanceProvider` just maps `dailyRoutineProvider`'s data.
- **No ranking.** It follows `DailyRoutine.currentStep`: step 1 → `ReviewsDue(count of the routine's item ids)`, step 2 → `RepeatedDifficulty(first mission target topic)` or, with no topics, `MatchesGoal` (first goal in `LearningGoal` declaration order) (the same stable choice the planner made) or `GenericMission`, step 3 → `WordsToReinforce(count of the routine's vocabulary ids)`, finished → `RoutineDone`, nothing to practice → `null`. The domain carries no text; `guidance_labels.dart` localizes it (it/en/es).
- **Source of truth.** The routine stays frozen for the day; new learning signals never change the guidance. Language isolation comes from the routine itself (one per day and learning language).
- **Home.** `RoutineCard` is the primary learning element: progress, current step, reason, one CTA that deep-links to the real step (`routineReview`, the mission via `startScenarioMission`, `routineWords`), step indicators (icon + words, never color alone) and a link to `DailyRoutineScreen`, which remains the full overview. Taps are ignored while a navigation is under way. `startScenarioMission` is the single place that turns a mission into a conversation, shared with `DailyRoutineScreen`.

## PHASE 10B — Mastery loop

```
Conversation ──► PracticeEvidence ──► LearningEngine ──► learning_memory
Review ─┬──► review_memory (schedule: status, interval, nextReviewAt)
        └──► PracticeEvidence ──► LearningEngine ──► learning_memory
```

`learning_memory` (what the system knows about the learner) and `review_memory` (what to review and when) stay separate stores with separate owners. `PracticeEvidence` is the contract that connects practice to the learning model; it is not a third store.

- **Contract.** `PracticeEvidence` (`learning/domain/practice_evidence.dart`): `eventId`, `source` (conversation | review), `type` (production | recognition | exposure), `outcome`, `learningLanguage`, `occurredAt`, and the item it is about (`referenceId`, `grammarTopic` = `GrammarTopic.name`, `vocabularyWord`). `PracticeEvidenceRecorder` is the only way in; `DefaultLearningEngine` implements it and is still the only writer of `learning_memory` (it is the only caller of `LearningRepository.applyPracticeEvidence`, which a test enforces).
- **Review → evidence.** `DefaultReviewEngine.recordReviewResult(…, exercise:)` keeps owning the schedule and, through its optional `evidence` recorder (wired to the learning engine in `review_providers.dart`), sends one event per answered attempt. It only reads the learning memory (to find an error's topic) and never imports a learning repository implementation. Items with no topic or word behind them (e.g. a spelling mistake) send nothing. The learning engine moves `learningRevisionProvider` when that evidence changes the memory (see *Phase 10B.1*); no UI changed.
- **Production vs recognition.** `ExerciseType.practiceType` classifies: error correction (typed) and vocabulary context (typed, no options) are production; grammar choice (picked from options) is recognition. Conversation counts as production.
- **Strength.** A fixed table (exact binary fractions, no AI, no randomness): conversation 1.0 > review production 0.5 > review recognition 0.25 when right / 0.375 when wrong > exposure 0.0625. Failures use the same scale. No call is repeated to simulate weight.
- **Model.** `GrammarTopicProgress` and `UserVocabulary` gain *weighted* counts (`weightedExposure/Errors/Successes`). `confidence` and `priority` use them; the plain counts still mean "times seen in the learner's own writing" and are what Percorso shows. Without review evidence the weighted counts equal the plain ones, so existing data and behaviour are unchanged. Review evidence moves only the weighted counts and never `lastSeenAt`. One success does not clear a weakness (topic: 2 errors + 1 typed success → confidence ≈ 0.2); it takes several to reach "improving" and leave the reinforce list.
- **Idempotency.** Review event id = `review:<itemId>:attempt:<n>` (n from the item's stored result counts). Applied review event ids are kept in `learning_memory.appliedEvents` (last 200). The evidence is sent *before* the schedule is saved, so if saving fails and the learner answers again the same id arrives and counts once. Conversation events have no identity outside the single analysis that made them and are not tracked. Details and limits in *Phase 10B.1*.
- **Persistence.** `learning_memory` stays version 1: the weighted fields and `appliedEvents` are additive and written only when they differ from the plain counts / are non-empty, so old data reads the same and conversation-only data is stored as before. `review_memory` is unchanged.
- **Language.** Evidence carries its language; a learning engine ignores another language's evidence and the repository only touches records of that language.
- **Daily routine / Guidance.** Unchanged. The day's routine is frozen; new evidence affects the next routine, guidance (derived from it), review priorities and the AI context.
## PHASE 10B.1 — Mastery loop integration cleanup

Technical cleanup of 10B; no new feature, weights, confidence, priority, progression rules or memory.

- **Single write path.** `DefaultLearningEngine` is the only caller of the `LearningRepository` write methods (a test scans `lib/` for it).
  ```
  Conversation ─► LearningEngine.analyze ─┬─► recordError / recordVocabulary (the mistakes themselves)
                                          └─► PracticeEvidence ─► applyPracticeEvidence
  Review ─► ReviewEngine ─► PracticeEvidenceRecorder (= LearningEngine) ─► applyPracticeEvidence
  ```
  Mistakes (`LearningError`) are not practice evidence, so they keep their own repository calls, still made only by the engine. Everything that proves command of a topic or a word is `PracticeEvidence`. `ReviewEngine` only reads the learning repository and writes through the recorder. `recordSuccessfulGrammarUse` and `clearLearningData` have no caller in the app; they stay in the repository contract.
- **Exposure.** Nothing produces `PracticeEvidenceType.exposure` today. The only other exposure path is a `topicExposure` signal without a mistake (`wasError` false), which the analysis never emits; the engine still handles it with a plain exposure, a full occurrence with no success, rather than as exposure evidence (weight 0.0625), because turning one into the other would silently re-weight it. It is inside the engine, so there is still one writer.
- **Learning revision.** `learningRevisionProvider` means "the learning data the screens read has changed". `DefaultLearningEngine.onMemoryChanged` is called after `analyze` wrote something (once per analysis, however many signals it wrote) and after `recordPracticeEvidence`/`apply` changed something; `learning_providers.dart` wires it to the revision, so it is the only place that moves it. It is not called for a repeated event, evidence of another language or about an unknown item, a review that proves nothing (e.g. a spelling mistake with no topic), or a write that failed. `ConversationController` and `ReviewSessionController` no longer touch it (the review's bump had been commented out by mistake).
- **Idempotency.** Review event id = `review:<itemId>:attempt:<n>`, `n = successfulReviews + failedReviews + 1` of the item as stored. `n` only grows (items are never deleted) and changes only when the schedule is saved. Order: the learning memory hears first, then the schedule is saved.
  - Schedule save fails or the app dies in between → the item keeps its `n`, the learner answers again, the same id arrives and is ignored by `appliedEvents` (also after a restart: it is persisted in `learning_memory`). The schedule then advances; the next answer is attempt `n+1` and counts.
  - The learning memory write fails → the id is not remembered (it is stored in the same write), so the retry applies once.
  - `appliedEvents` keeps the last 200 ids (kept; not raised). An id can only come back by repeating an attempt number of the same item, which needs the item to be re-created, and review items are never deleted. A retry is the very next answer to the same item, so 200 later events in between is not a real path.
  - Conversation evidence is not tracked: `analyze` runs once per assistant reply (a retry only re-asks a reply that failed, before any analysis), so the same message is not analyzed twice.
- **Known limitations (for Phase 11B).**
  - If `review_memory` is lost or reset while `learning_memory` survives, items are discovered again with `n = 1` and, if those ids are still in the last 200, their first new answers are ignored by the learning memory (the review still schedules them).
  - A retry carries the same id as the first answer even if its outcome differs; the learning memory keeps the first.
  - If the learning memory cannot be written when a review is answered, that evidence is lost (the review is never blocked, and nothing replays it).
  - `isImprovingTopic` and `confidence` do not tell production from recognition; the weights of a conversation success do not use the detection's confidence. Phase 11B adds a separate ledger that does tell them apart; these two are unchanged.

## PHASE 11B — Adaptive Learning State

What the learner needs next is decided **per concept** (a grammar topic or a word), never for the learner as a whole. The declared level (A1–B2) is not read, written or inferred by any of this.

```
Conversation ─► LearningEngine.analyze(contextId) ─┐
                                                   ├─► PracticeEvidence ─► applyPracticeEvidence ─► learning_memory
Review ─► ReviewEngine ─► PracticeEvidenceRecorder ┘          (counters as in 10B  +  PracticeProof ledger)
                                                                           │ derived, never stored
                                                  LearningState ─► AdaptationStrategy ─► prompt · scenario · exercise
```

- **Where it lives.** `learning/domain/learning_state.dart`: `LearningState`, `AdaptationStrategy`, `LearningStatePolicy` (every threshold) and `PracticeProof`. A concept (`GrammarTopicProgress`, `UserVocabulary`) carries one `proof` and exposes `learningState`. No new store, no new write path: the proof changes in the same `applyPracticeEvidence` call, inside the same single write of `learning_memory`, so the 10B.1 idempotency (event ids, `appliedEvents`) and revision semantics (`onMemoryChanged`, only when memory really changes) apply to it unchanged. Weights, `confidence`, `priority`, `isImprovingTopic` and `ReviewStatus` are untouched.
- **Recognition vs production.** `PracticeEvidence.type` decides. *Production* is what the learner wrote or typed: a conversation message, a typed correction, a typed missing word. *Recognition* is picking among given options (the grammar choice). *Exposure* is only seeing it and changes nothing. Recognition has its own counters, can reveal a difficulty (a failed one makes the concept WEAK) but never counts as a correct production, never opens an interaction, never enters the recent outcomes and so never proves anything. Each `ExerciseType` declares its type in one place (`ExercisePracticeType`).
- **The ledger (`PracticeProof`).** Counters of correct/wrong production and recognition; the last 5 production outcomes; the last 5 distinct interactions in which a production was correct. Bounded. Stored as an optional `proof` object in the topic/word entry of `learning_memory` (still version 1, additive, written only when non-empty).
- **Interactions (contexts).** `PracticeEvidence.contextId`: for conversation, `conversation:<conversation id>` (passed by `ConversationController` through `LearningEngine.analyze(contextId:)`); for review, `review:<utc day>` (the review has no session id the engine knows, so all answers of one day are one context, the conservative side). Evidence without one counts as a single `unknown` interaction. Repeating the same interaction never counts twice.
- **`productionProven`** = at least 2 correct productions, and among the last 5 productions no more failures than successes. It is never set by recognition, by exposure, by a word merely found, by an AI correction or by app-generated text.
- **States** (`PracticeProof.stateOf`):
  - **NEW**: nothing shows a difficulty and production is not proven.
  - **WEAK**: any difficulty (a mistake in conversation, a failed production, a failed recognition) and production not proven.
  - **IMPROVING**: production proven.
  - **CONSOLIDATED**: proven, at least 3 correct productions in at least 2 interactions, and at most 1 failure among the last 5 productions.
- **Transitions** follow from that, with the evidence as it arrives: NEW→WEAK on a production error; NEW→IMPROVING on the 2nd correct production; WEAK→IMPROVING when 2 correct productions outweigh the recent failures (one isolated success never moves it); IMPROVING→CONSOLIDATED on the 3rd correct production if they span 2 interactions. NEW or WEAK never reach CONSOLIDATED in one step (a test walks every sequence of up to 7 pieces of evidence). CONSOLIDATED is not permanent: an isolated error (`✓ ✓ ✗ ✓`) keeps it; a second failure among the last 5 takes it to IMPROVING, and failures outnumbering successes take it to WEAK. Getting back needs a calm record again.
- **Strategy** (one table, `LearningState.strategy`): NEW→KEEP, WEAK→SIMPLIFY, IMPROVING→KEEP, CONSOLIDATED→STRETCH.
  - **Conversation.** `buildLearningContext` adds `topicStrategies` (the topics to reinforce, with the strategy of their own state, plus up to 2 consolidated topics) and `stretchWords` (up to 3 consolidated words). The teacher prompt gets a "Difficulty by area" section, only when there is something in it, that says the overall level does not change and asks for guided/simple, same-difficulty-with-varied-examples, or less-guided/new-context practice for the named topics. The existing lines of the prompt are unchanged.
  - **Scenarios.** `ScenarioGenerator` keeps the same scene, topics and id, and adds to the mission prompt: a low demand for the weak topics only, and a request for more where the learner is consolidated.
  - **Exercises.** `Exercise.adaptation` records the strategy it was built with. A WEAK topic gets a guided grammar choice (the right form against the learner's mistake, 2 options); IMPROVING and CONSOLIDATED get the usual up-to-4 options. It is still a choice, so it is still recognition.
- **Level.** A learner at B1 can be STRETCH on one concept and SIMPLIFY on another and is still B1: nothing here touches `UserLearningProfile`, and tests check the prompt keeps the declared level and that the learning-state code does not import the profile.
- **Known limits.**
  - History from before 11B has no ledger: its mistakes make a topic WEAK, but earlier successes do not count as production proof. A concept needs new production to leave WEAK (conservative on purpose).
  - Nothing decays with time: a consolidated concept stays so until failures say otherwise.
  - A review "context" is a day; two sessions the same day are one interaction.
  - Conversation successes are detected by wording (as in 10B), so a structural match counts as a correct production like a literal one.
  - Review of an error is typing the corrected sentence the learner already saw: it counts as production but can be memorized.
  - Vocabulary and error-correction exercises have no adaptation lever that needs no new UI, so only the grammar choice adapts; STRETCH on a grammar choice is the same as KEEP. Per-exercise hints, harder exercise kinds and a UI for any of it are out of scope.
  - A topic that is both to reinforce (by the 10B rules) and CONSOLIDATED (by this one) is listed under both; the strategy line follows the state.
  - An older app version that rewrites `learning_memory` drops the `proof` fields it does not know.
  - No automatic level change, no new weights and no AI decides any state (out of scope).

## PHASE 12 — Adaptive learning integration (verification)

An audit of the circuit built in 10B–11B found it closed; no production code changed in this phase.

```
practice ─► PracticeEvidence ─► DefaultLearningEngine ─► learning_memory
   ▲        (2 constructors: conversation, review)        (single writer)
   │                                                           │
   └── conversation · scenario · exercise ◄── AdaptationStrategy ◄── LearningState
```

- **One interpretation.** The conversation context, the scenario and the exercise generator all derive their strategy from `LearningState.strategy` (via `selectTopicStrategies` or the topic's own `learningState`); none switches on the state itself, and no other type plays the role of a difficulty hint.
- **Evidence.** `PracticeEvidence` is built in two places only (`DefaultLearningEngine._conversationEvidence`, `DefaultReviewEngine._evidenceFor`). The daily routine's vocabulary step and the guidance write nothing.
- **Level.** The only reader of the declared level for teaching is `_levelGuidance` in the teacher prompt.
- **Test.** `test/features/learning/adaptive_loop_test.dart` runs the circuit from a real stored memory (conversation → WEAK → IMPROVING → CONSOLIDATED, checking the teacher's instruction, the scenario and the exercise at each stage, then a restart) plus the evidence and review-session flows. Unchanged and still true: 10B weights, 11B thresholds, 10B.1 revision and idempotency semantics, and the known limitations listed in Phase 11B.

## PHASE 13 — Bilingual conversation

The teacher speaks the language being learned (*target*); under it, the learner reads the same words in their support language (*translation*). It is a comprehension aid around the conversation, not a second conversation and not part of learning.

- **Data.** Three optional fields, one source of truth each, all `null` when absent: `AIResponse.translation` (the message in the support language), `Correction.correctedTranslation` (the **corrected** sentence in the support language) and `ConversationMessage.translation` (the stored copy of the first). The target text (`message`, `corrected`) stays the authoritative content; nothing is derived from the translation.
- **Where it is asked.** The teacher instruction (`teacher_prompt.dart`) adds a "Translation" block, parameterized by the support language's name and present only when the two languages differ: translate `message` faithfully; translate the *corrected* sentence of each correction, never the learner's mistaken one; use `null` if it cannot be done faithfully. `GeminiAIService.outputFormatInstruction` only declares the two JSON fields. No code branches on any language: they travel as parameters, so every pair works the same.
- **Parsing.** `parseAssistantPayload` and `Correction.tryFromJson` accept a translation only as a non-empty string; anything else is "no translation". A missing or malformed translation never fails or empties a reply (the plain-text fallback has none either).
- **Persistence.** `conversations` stays version 1. `translation` / `correctedTranslation` are written only when present and read leniently, so everything stored before reads as before with no migration.
- **UI.** In `MessageBubble` the target text is first, in the existing style; the translation is a second, italic, lower-contrast line with a translate icon (`TranslationLine`) **inside the same bubble**, with a localized semantics label. `CorrectionCard` shows *you wrote → better → its translation*. Learner messages never show one. Listening still reads the target only.
- **Not learning.** `LearningEngine.analyze` reads `original` and `corrected` and nothing else; the translation creates no `PracticeEvidence`, changes no state, proof, confidence, priority, revision or level, and is neither stored in `learning_memory` nor sent back to the AI as history (`_contextFor` uses `content` only). Tests compare the learning memory of the same exchange with and without translations: identical.
- **Known limits.** The translation is the model's: there is no check that it matches the target, apart from the prompt. Each reply is a bit longer (more tokens and latency). There is no show/hide control: it fits no existing preference mechanism and would need a new one (out of scope). Learner messages are not translated, and neither are explanations or "more natural" alternatives.

## PHASE 14 — Teacher voice (female / male)

- **Provider (unchanged).** Reading aloud is the device's own text-to-speech engine through `flutter_tts` behind `SpeechService` (`FlutterTtsSpeechService`): no network, no key, no new dependency. Before this phase it set only the language, so the voice was whatever the engine's default is for it. Gemini is not involved in speech.
- **Preference.** `VoiceGender { female, male }` (`shared/models/voice_gender.dart`) stored as `UserLearningProfile.teacherVoice` in the existing profile document (`teacherVoice`, optional; absent or unknown reads as `female`, which is what every existing user already hears). It is edited in the Profile screen (`SegmentedButton`, same card style as "Read replies aloud") and is not learning data: it is in no learning/review memory, no `PracticeEvidence`, no `ConversationMessage`.
- **Who passes it.** `SpeechController.speak` reads the profile when it speaks, so the next reading uses the new choice. `ConversationController` and `ListenButton` still pass the text and the learning language only; what is read is the target-language message (or a correction's corrected sentence), never the Phase 13 translation, and the locale comes from the learning language.
- **Resolution.** `resolveVoice(voices, localeTag, gender)` (`services/speech/voice_resolver.dart`, pure): only voices of the language of the locale (exact locale first); a voice the engine itself declares as the wanted gender (a whole word `female`/`male` in its name or features) wins, best quality and installed over network; otherwise the engine's own voice with a pitch that approximates the gender (natural for female, `maleFallbackPitch` 0.8 for male). If the engine declares genders but none matches, an undeclared voice is preferred to one of the other gender. It never returns a voice of another language and never fails.
- **Fallback.** `FlutterTtsSpeechService` applies the voice after `setLanguage`, always sets the pitch (so a male reading never leaks into the next female one), asks the engine for its voices once, and ignores any problem choosing a voice: the reading goes on with the engine's default voice. No voice for the language is still `SpeechOutcome.noVoice` with the existing message.
- **Not learning.** Playing, stopping or changing the voice writes nothing but the profile (when the voice is changed): tests compare `learning_memory`, `review_memory`, `conversations` and `learningRevision` before and after.
- **Real limit.** Android's `Voice` API has no gender. `flutter_tts` reports name, locale, quality, latency, network and features, and Google's engine names (`it-it-x-itb-local`) do not say it. So on most phones a "male" voice is the default voice at a lower pitch, an approximation, not a different speaker. Real gendered voices need an engine that declares them or a provider with named voices (for example Gemini speech, which would add network, cost, an audio player and PCM handling): out of scope, noted as a future option.
- **Not validated on a device.** The voices actually installed, how the lowered pitch sounds and which languages have which voices can only be judged on a phone.

## PHASE 15 — Natural voice engine (evaluation; platform TTS kept)

Gemini TTS was evaluated against the project's real key and **not adopted**: the speech provider is still the device engine of Phase 14 (`flutter_tts` behind `SpeechService`). What changed is what the engine is given.

- **Done: spoken text.** `spokenText` (`voice/domain/speech_text.dart`) turns the text shown on screen into the text to say: no emoji (the teacher prompt itself shows "Quasi! 😊"), no markdown marks, links reduced to their words, whitespace folded. `SpeechController` applies it for every reading, whatever the provider; the visible text, the translation (never spoken) and the spelling mode are unaffected.
- **Verified about Gemini TTS (calls made on 2026-10-08, official docs and real requests).**
  - API: the current docs describe the Interactions API (`POST /v1beta/interactions`, `response_format: {type: audio}`, `generation_config.speech_config: [{voice}]`, style as a `speech_metadata` annotation on the text), models `gemini-3.8-flash-tts` and `gemini-3.8-flash-lite-tts`. Output for a unary call is a base64 WAV, 24 kHz, mono, 16-bit (about 48 KB per second of speech). Streaming is `audio/l16` over SSE.
  - Voices with real gender: `GET /v1beta/voices?language_code=&gender=&type=prebuilt&context=` returns library voices with `gender`, `persona`, `context`, `pitch`; a library voice id (e.g. `it-it-tutor-7`) is accepted as `voice`. There is a "Conversational / Edu" context with tutor personas. The 30 named voices (Kore, Puck...) have no documented gender. Voices found per locale: it-IT 27 f / 25 m, en-US 50 / 50, es-ES 9 / 12 (no female in the edu context), fr-FR 48 / 28, de-DE 39 / 46, pt-BR 50 / 50, **zh-CN none** (no Mandarin voice in the library, under any code tried).
  - Generation worked for Italian (female and male library voices, two models) and English. The other languages' voices were found but not synthesized (see quota).
  - **Latency** (non-streaming): about 4–6 s for a short sentence, about 6–8 s for a 4-sentence message (12 s of audio). First sound can only start after that; streaming would need an SSE and raw-PCM player.
  - **Quota of the key tested (free tier): 3 requests per minute and 10 requests per day for `gemini-3.8-flash-tts`.** Every Play tap is a request, so one session of reading replies exhausts it. The daily quota of that model was used up by this evaluation.
- **Why it was not adopted.** (1) The free-tier quota makes it unusable as the main voice; a paid tier would need to be confirmed. (2) 4–8 s before each reading. (3) No Mandarin voice. (4) There is no audio-playback dependency in the project and nothing can be validated without a device: not the playback, not whether it sounds better, which is the whole point. (5) A half-validated migration is worse than a stable fallback. Phase 14 is intact.
- **What a future phase would need.** A confirmed paid quota (or a server-side proxy: the key is client-side today, as for chat); a measured decision on streaming vs. waiting; an audio player (WAV bytes to a temporary file) and a stop/replace policy; a resolver `learningLanguage + VoiceGender -> library voice` (query the library with `language_code` from `speechLocaleTag`, the gender, `type=prebuilt`, preferring the "Conversational / Edu" context and tutor personas, cached per locale and gender), with the platform TTS as fallback on any error, 429, unsupported language (Mandarin) or timeout; an A/B listening test on a phone. Not implemented: no speed setting, no caching, no provider switch.
- **Unchanged.** No learning code, no learning/review memory, no `PracticeEvidence`, no revision: reading aloud is still presentation only.

## PHASE 16 — Italian teacher voices from Google's engine, with fallback

The provider is unchanged (`flutter_tts` behind `SpeechService`, Google's engine on the test phone). What changed is which voice reads Italian.

- **The voices.** Chosen by a person listening on the phone (Phase 15.1), not inferred from names: **female = `it-it-x-itb-network`, male = `it-it-x-itd-network`**, both Google server voices. They live in one table, `preferredVoiceNames` (`voice_resolver.dart`), keyed by locale (`it-it`) and `VoiceGender`, each with its installed twin as the second choice (`itb-local`, `itd-local`). Any other locale is not in the table and keeps the generic resolution of Phase 14 (the engine's own voice; for male a lowered pitch). Adding a language later means adding an entry that someone has listened to.
- **The chain.** `resolveVoiceChain` returns what to try, best first: the preferred voices the device really has, then what `resolveVoice` has always chosen, then the engine's own voice. A pitch is only used in those last, generic steps: an Italian male voice is a real voice, never a lowered one, unless both preferred voices fail.
- **How a reading ends.** `FlutterTtsSpeechService` tries each voice in turn. An engine error, a refused voice, or (for a voice that needs the network) not starting within 8 s moves on to the next. A reading stopped by the learner counts as read. Because the plugin reports an error but never completes `speak`, every attempt is raced against the error callback, the start callback and a cap of 15 s + 120 ms per character (twice when slow); if the cap runs out the engine is considered dead, the reading ends as `failed` and no other voice is tried (it could read over the first). The controller always goes back to idle and Listen works again.
- **What the phone did.** Online: the server voice (`itb-server` / `itd-server`) started in about 0.5–1 s. With no internet at all (Wi-Fi and data off) the engine itself served the same request with its installed twin (`itb-seanet-embedded` / `itd-seanet-embedded`, logged as "local fallback") starting at once, so the app's own fallback was not needed there. The app's chain is the safety net for when the engine does report an error.
- **Unchanged.** `VoiceGender` and `UserLearningProfile.teacherVoice` (persisted, still the only thing the user sees: Female / Male), `spokenText`, the correction Listen (only the corrected phrase) and the Phase 13 translation (never spoken). Speech writes nothing: no `PracticeEvidence`, no learning/review memory, no revision, no state. No Gemini, no audio player, no cache.
- **Limits.** The preference is Italian only and depends on Google's engine and its voice names; a phone without them falls back to the generic voice. A server voice needs the network and is slower to start; whether the installed twin sounds as natural as the server voice is a listening judgment not made here. If the system kills the engine's process the plugin cannot reconnect: readings answer "no voice" until the app is restarted (the button is no longer left on "stop").

## Configuration & security
`AppConfig` reads `--dart-define` values: `APP_ENV` (`development` default | `production`), `GEMINI_API_KEY`, `GEMINI_MODEL`, `AI_PROXY_URL` (reserved, not used yet). Nothing secret is in source. Put them in `env/dev.json` (git-ignored; `env/dev.example.json` is versioned) and run:
```
flutter run --dart-define-from-file=env/dev.json
```
**Limitation:** any key compiled into an APK can be extracted, so it is never an absolute secret. This is tolerable only for a personal development MVP using a restricted/revocable key. Do not distribute a build containing a real key. Production should be `Flutter app -> secure backend/proxy -> Gemini`: implement the proxy as a new `AIService` (using `AI_PROXY_URL`) and change the `aiServiceProvider` binding; UI, controller and domain stay unchanged.

## Android
Placeholder application id `com.parlaconme.parla_con_me` (change before any store release). Only `INTERNET` is declared (used by the Gemini calls). `RECORD_AUDIO` is intentionally absent and will be added with the audio/speech phase, together with runtime permission handling.

## Dependencies
| Package | Why |
|---|---|
| `flutter_riverpod` | State management + DI |
| `go_router` | Declarative routing, shell/tab navigation, redirects |
| `shared_preferences` | First `LocalStorage` implementation |
| `http` | Single networking client, used only inside `GeminiAIService` (REST). The Gemini SDK `google_generative_ai` is deprecated and its successor requires Firebase, so REST was chosen |

No AI SDK, database, Firebase, Supabase, analytics or auth packages.

## Future backend / Supabase migration
1. Add remote implementations of the repository interfaces (and a sync wrapper over the local one); features keep using the interfaces.
2. Move Gemini behind a server-side proxy; switch the `aiServiceProvider` binding.
3. Introduce auth and user identity only then; local data can be uploaded as the initial sync.
Nothing in PHASE 0 assumes a backend exists, and nothing prevents adding one.

## Quality
`flutter analyze` (flutter_lints + strict-casts/raw-types + a few extra rules), `dart format`, tests in `test/` (unit + widget; `integration_test/` to be added when needed).
