# Parla con me!

AI-powered Italian tutor (Android, Flutter). Currently at PHASE 2 (text
conversation with the AI teacher).
See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Run

```
flutter pub get
flutter analyze
flutter test
```

### Gemini API key (required for the conversation)

The key is never stored in the repository. Copy the example file, put your key
in the copy, and pass it at build/run time:

```
copy env\dev.example.json env\dev.json     # then edit env\dev.json
flutter run --dart-define-from-file=env/dev.json
```

`env/*.json` is git-ignored (only `env/*.example.json` is versioned). Without a
key the app runs, and Parla shows a friendly "not configured" message.
`GEMINI_MODEL` can be changed in the same file.

Note: a key compiled into an APK can be extracted. Use a restricted, revocable
key and do not distribute builds that contain it. See the security section of
the architecture doc.
