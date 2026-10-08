import '../../shared/models/voice_gender.dart';

/// A voice the device's speech engine offers, as `flutter_tts` describes it.
/// The platform does not say whether a voice is female or male: the only
/// hints are in its name and features (see [declaredGender]).
class DeviceVoice {
  const DeviceVoice({
    required this.name,
    required this.locale,
    this.quality = 2,
    this.networkRequired = false,
    this.features = '',
  });

  final String name;

  /// BCP-47 tag, e.g. `it-IT`.
  final String locale;

  /// 0 (very low) to 4 (very high); 2 when the engine does not say.
  final int quality;
  final bool networkRequired;
  final String features;

  /// Reads one entry of `FlutterTts.getVoices`; `null` when it is not usable.
  static DeviceVoice? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final locale = raw['locale'];
    if (name is! String || name.isEmpty) return null;
    if (locale is! String || locale.isEmpty) return null;
    final features = raw['features'];
    return DeviceVoice(
      name: name,
      locale: locale,
      quality: switch ('${raw['quality']}'.toLowerCase()) {
        'very high' => 4,
        'high' => 3,
        'low' => 1,
        'very low' => 0,
        _ => 2,
      },
      networkRequired: '${raw['network_required']}' == '1',
      features: features is String ? features : '',
    );
  }

  /// `female` or `male` when the engine says so in the voice's name or
  /// features (as whole words), otherwise `null`. Most engines, Google's
  /// included, say nothing, which is why [resolveVoice] has a fallback.
  VoiceGender? get declaredGender {
    final words = '$name $features'.toLowerCase().split(RegExp('[^a-z]+'));
    if (words.contains('female')) return VoiceGender.female;
    if (words.contains('male')) return VoiceGender.male;
    return null;
  }
}

/// Voices chosen by a person listening to them on a real phone (Phase 15.1),
/// per locale (lowercase BCP-47 tag) and gender, in the order to try them:
/// first the Google server voice, then its installed twin. The engine does not
/// say the gender of any voice, so this is the only place that knows it, and
/// it is only known for what was listened to: Italian on Google's engine.
/// A locale that is not here keeps the generic resolution below. The names are
/// Google TTS identifiers; a device that lacks them simply skips them.
const preferredVoiceNames = <String, Map<VoiceGender, List<String>>>{
  'it-it': {
    VoiceGender.female: ['it-it-x-itb-network', 'it-it-x-itb-local'],
    VoiceGender.male: ['it-it-x-itd-network', 'it-it-x-itd-local'],
  },
};

/// The voice to speak with and how to speak it.
class ResolvedVoice {
  const ResolvedVoice({
    required this.voice,
    required this.pitch,
    required this.genderMatched,
  });

  /// `null` means the engine's own voice for the language (what the app used
  /// before the learner could choose).
  final DeviceVoice? voice;

  /// 1.0 is the voice's natural pitch.
  final double pitch;

  /// A voice that the engine itself declares as the wanted gender was found.
  final bool genderMatched;
}

/// The pitch used to approximate a male voice when the device offers no voice
/// it declares as male. An approximation, not a real male voice.
const maleFallbackPitch = 0.8;

/// The pitch that goes with [gender] when no voice of that gender was found.
double fallbackPitch(VoiceGender gender) =>
    gender == VoiceGender.male ? maleFallbackPitch : 1.0;

/// Chooses the voice for [localeTag] and [gender] among [voices]. Pure.
///
/// 1. Only voices of the language of [localeTag] are considered, those of the
///    exact locale first.
/// 2. A voice the engine declares as [gender] wins; among them the better
///    quality, installed over network, then by name.
/// 3. Otherwise the engine's own voice (`voice == null`) with a pitch that
///    approximates the gender: natural for female, lowered for male. If the
///    engine does declare genders but none matches and a voice of undeclared
///    gender exists, that one is used instead of a voice of the other gender.
///
/// It never fails and never picks a voice of another language. For a locale
/// with [preferredVoiceNames] it is the first preferred voice the device has;
/// [resolveVoiceChain] gives every voice to try, in order.
ResolvedVoice resolveVoice({
  required List<DeviceVoice> voices,
  required String localeTag,
  required VoiceGender gender,
}) => resolveVoiceChain(
  voices: voices,
  localeTag: localeTag,
  gender: gender,
).first;

/// Everything to try for [localeTag] and [gender], best first, never empty:
/// the preferred voices the device really has (see [preferredVoiceNames]), at
/// the natural pitch, then what [resolveVoice] has always chosen (a voice the
/// engine declares, or its own voice with a pitch that approximates the
/// gender), and last the engine's own voice. A pitch is only ever used in those
/// generic steps.
List<ResolvedVoice> resolveVoiceChain({
  required List<DeviceVoice> voices,
  required String localeTag,
  required VoiceGender gender,
}) {
  final wanted = _normalize(localeTag);
  final names = preferredVoiceNames[wanted]?[gender] ?? const <String>[];
  final generic = _resolveGeneric(voices, localeTag, gender);
  return [
    for (final name in names)
      for (final v in voices)
        if (v.name == name && _normalize(v.locale) == wanted)
          ResolvedVoice(voice: v, pitch: 1.0, genderMatched: true),
    generic,
    // The last resort is always the engine's own voice, which cannot be
    // refused, in case it refuses the one chosen above.
    if (generic.voice != null)
      ResolvedVoice(
        voice: null,
        pitch: fallbackPitch(gender),
        genderMatched: false,
      ),
  ];
}

ResolvedVoice _resolveGeneric(
  List<DeviceVoice> voices,
  String localeTag,
  VoiceGender gender,
) {
  final wanted = _normalize(localeTag);
  final language = wanted.split('-').first;
  final candidates = [
    for (final v in voices)
      if (_normalize(v.locale).split('-').first == language) v,
  ]..sort((a, b) => _compare(a, b, wanted));

  for (final v in candidates) {
    if (v.declaredGender == gender) {
      return ResolvedVoice(voice: v, pitch: 1.0, genderMatched: true);
    }
  }
  final anyDeclared = candidates.any((v) => v.declaredGender != null);
  DeviceVoice? neutral;
  if (anyDeclared) {
    for (final v in candidates) {
      if (v.declaredGender == null) {
        neutral = v;
        break;
      }
    }
  }
  return ResolvedVoice(
    voice: neutral,
    pitch: fallbackPitch(gender),
    genderMatched: false,
  );
}

String _normalize(String tag) => tag.replaceAll('_', '-').toLowerCase();

int _compare(DeviceVoice a, DeviceVoice b, String wanted) {
  final aExact = _normalize(a.locale) == wanted ? 0 : 1;
  final bExact = _normalize(b.locale) == wanted ? 0 : 1;
  if (aExact != bExact) return aExact.compareTo(bExact);
  if (a.quality != b.quality) return b.quality.compareTo(a.quality);
  if (a.networkRequired != b.networkRequired) {
    return a.networkRequired ? 1 : -1;
  }
  return a.name.compareTo(b.name);
}
