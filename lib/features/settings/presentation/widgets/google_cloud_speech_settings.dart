import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';

/// API key entry for the Google Cloud speech engine — its own small
/// stateful widget (rather than inline in [SettingsScreen]) so the
/// [TextEditingController] survives the parent rebuilding on every settings
/// change without losing cursor position or getting fed a "controller and
/// value changed" assertion.
class GoogleCloudSpeechSettings extends ConsumerStatefulWidget {
  const GoogleCloudSpeechSettings({super.key, required this.apiKey});

  final String? apiKey;

  @override
  ConsumerState<GoogleCloudSpeechSettings> createState() => _GoogleCloudSpeechSettingsState();
}

class _GoogleCloudSpeechSettingsState extends ConsumerState<GoogleCloudSpeechSettings> {
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
              labelText: 'Google Cloud API key',
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
            'From Google Cloud Console: enable the "Cloud Speech-to-Text API", create an API key, then '
            'restrict it to Android apps using package com.aivoicedocs.app. Stored only on this device '
            '— never bundled with the app or sent anywhere except Google\'s API.',
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
    ref.read(settingsControllerProvider.notifier).setGoogleCloudApiKey(value.isEmpty ? null : value);
  }
}
