import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/config/app_env.dart';

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
    final hasBundledKey = AppEnv.sarvamApiKey.isNotEmpty;
    final usingBundledKey = hasBundledKey && (widget.apiKey?.trim().isEmpty ?? true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (usingBundledKey) ...[
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Using the key from your .env file',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _controller,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Sarvam AI API key',
              hintText: usingBundledKey ? 'Leave blank to use the .env key' : null,
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
            hasBundledKey
                ? 'A key here overrides the one in .env, so you can swap keys without rebuilding. '
                      'Clear the field to go back to the .env key.'
                : 'From dashboard.sarvam.ai: sign in and copy your API subscription key. Stored only '
                      'on this device — never sent anywhere except Sarvam\'s API.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Uses Sarvam\'s saaras:v4 model — built for Indian languages, and handles English too. '
            'Other languages fall back to auto-detect and may transcribe poorly; use the on-device '
            'engine for those.',
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
