import 'dart:convert';
import 'dart:io';
import 'package:ai_voice_docs/core/privacy/privacy_policy.dart';

Future<void> main(List<String> args) async {
  final draft = args.contains('--draft');
  final paths = args.where((a) => !a.startsWith('--')).toList();
  final file = File(paths.isEmpty ? 'release/identity.json' : paths.first);
  if (!await file.exists()) {
    stderr.writeln(
      'Missing release identity. Copy release/identity.example.json to release/identity.json and fill it in.',
    );
    exitCode = 1;
    return;
  }
  final identity =
      jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final developer = (identity['DEVELOPER_NAME'] as String? ?? '').trim();
  final email = (identity['SUPPORT_EMAIL'] as String? ?? '').trim();
  final url = (identity['PRIVACY_POLICY_URL'] as String? ?? '').trim();
  final uri = Uri.tryParse(url);
  final problems = <String>[
    if (developer.isEmpty || developer.contains('YOUR_')) 'Set DEVELOPER_NAME.',
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        email.endsWith('@example.com'))
      'Set a real SUPPORT_EMAIL.',
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host == 'example.com' ||
        uri.userInfo.isNotEmpty ||
        uri.host.endsWith('.example'))
      'Set your public HTTPS PRIVACY_POLICY_URL.',
  ];
  if (!draft && problems.isNotEmpty) {
    stderr.writeln(problems.join('\n'));
    exitCode = 1;
    return;
  }
  const escape = HtmlEscape();
  String html(String value) => escape.convert(value);
  final output = Directory('release/generated');
  await output.create(recursive: true);
  final policy =
      '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Voice Docs AI Privacy Policy</title>
<style>body{font:17px/1.65 system-ui,sans-serif;color:#202134;background:#fbfaf7;max-width:760px;margin:auto;padding:32px 20px}h1,h2{line-height:1.3}h2{margin-top:36px}a{color:#4140a0}.draft{padding:16px;background:#fff2cf}</style>
<main><h1>Voice Docs AI Privacy Policy</h1><p>Effective ${ReleaseIdentity.policyDate}</p>
${draft ? '<p class="draft">DRAFT — configure developer identity and contact before publishing.</p>' : ''}
${privacySections.entries.map((s) => '<h2>${html(s.key)}</h2><p>${html(s.value)}</p>').join('\n')}
<h2>Developer contact</h2><p>${html(developer.isEmpty ? 'Developer name required' : developer)}<br>
${email.isEmpty ? 'Support email required' : '<a href="mailto:${html(email)}">${html(email)}</a>'}</p>
<p>${html(url)}</p></main></html>''';
  await File('${output.path}/privacy-policy.html').writeAsString(policy);
  await File('${output.path}/privacy-policy.txt').writeAsString(
    'Voice Docs AI Privacy Policy\nEffective ${ReleaseIdentity.policyDate}\n\n'
    '${privacySections.entries.map((s) => '${s.key}\n${s.value}').join('\n\n')}\n\n'
    'Developer: $developer\nSupport: $email\nPublic policy: $url\n',
  );
  stdout.writeln(
    draft
        ? 'Draft policy generated; not ready to publish.'
        : 'Public policy generated. Publish it at your configured URL before release.',
  );
}
