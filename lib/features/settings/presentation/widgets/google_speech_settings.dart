import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_voice_docs/core/config/app_env.dart';

import '../providers/settings_providers.dart';

/// API key entry for the Google Cloud speech engine — its own small stateful
/// widget (rather than inline in [SettingsScreen]) so the
/// [TextEditingController] survives the parent rebuilding on every settings
/// change without losing cursor position or getting fed a "controller and
/// value changed" assertion.
class GoogleSpeechSettings extends ConsumerStatefulWidget {
  const GoogleSpeechSettings({super.key, required this.apiKey});

  final String? apiKey;

  @override
  ConsumerState<GoogleSpeechSettings> createState() => _GoogleSpeechSettingsState();
}

class _GoogleSpeechSettingsState extends ConsumerState<GoogleSpeechSettings> {
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
    final hasBundledKey = AppEnv.googleSpeechApiKey.isNotEmpty;
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
              labelText: 'Google Cloud API key',
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
                : 'From console.cloud.google.com: create a project, enable billing, enable the '
                      '"Cloud Speech-to-Text API", then create an API key under Credentials. Stored '
                      'only on this device — never sent anywhere except Google\'s API.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Broad language coverage, not limited to any one region — takes whatever language '
            'you pick directly, no translation needed. Bills per use once past the free monthly tier.',
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
    ref.read(settingsControllerProvider.notifier).setGoogleSpeechApiKey(value.isEmpty ? null : value);
  }
}
