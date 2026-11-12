import 'package:flutter/material.dart';
import 'privacy_policy.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy policy')),
    body: SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Voice Docs AI',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Effective ${ReleaseIdentity.policyDate} · Available offline',
          ),
          const SizedBox(height: 20),
          for (final section in privacySections.entries) ...[
            Text(section.key, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(section.value),
            const SizedBox(height: 24),
          ],
          Text(
            ReleaseIdentity.developerName.isEmpty
                ? 'Preview build: developer contact has not been configured.'
                : 'Developer: ${ReleaseIdentity.developerName}',
          ),
          if (ReleaseIdentity.supportEmail.isNotEmpty)
            const Text('Support: ${ReleaseIdentity.supportEmail}'),
          if (ReleaseIdentity.privacyUrl.isNotEmpty)
            const Text('Public policy: ${ReleaseIdentity.privacyUrl}'),
        ],
      ),
    ),
  );
}
