import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';

/// API key entry for the Sarvam AI speech engine — its own small stateful
/// widget (rather than inline in [SettingsScreen]) so the
/// [TextEditingController] survives the parent rebuilding on every settings
/// change without losing cursor position or getting fed a "controller and
/// value changed" assertion.
class SarvamSpeechSettings extends ConsumerStatefulWidget {
  const SarvamSpeechSettings({super.key, required this.apiKey});

  final String? apiKey;

  @override
  ConsumerState<SarvamSpeechSettings> createState() => _SarvamSpeechSettingsState();
}

class _SarvamSpeechSettingsState extends ConsumerState<SarvamSpeechSettings> {
  late final TextEditingController _controller = TextEditingController(text: widget.apiKey);
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Sarvam AI API key',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: _obscure ? 'Show key' : 'Hide key',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onEditingComplete: _save,
            onTapOutside: (_) => _save(),
          ),
          const SizedBox(height: 10),
          Text(
            'From dashboard.sarvam.ai: sign in and copy your API subscription key. Stored only on '
            'this device — never bundled with the app or sent anywhere except Sarvam\'s API.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Best for Indian languages. Other languages fall back to Sarvam\'s auto-detect and may '
            'transcribe poorly — use the on-device engine for those.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Note: no live captions in this mode — you\'ll see the transcript right after you stop '
            'talking, not word-by-word while speaking.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _save() {
    final value = _controller.text.trim();
    ref.read(settingsControllerProvider.notifier).setSarvamApiKey(value.isEmpty ? null : value);
  }
}
