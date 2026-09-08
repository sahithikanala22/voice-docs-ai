import 'package:intl/intl.dart';

/// The `DD-MM-YYYY_HH-MM` timestamp used in every exported/shared file's
/// name (backups, PDF/Word exports) — e.g.
/// `voicedocsai_07-09-2026_12-34.pdf`. Dashes between the date/time parts
/// so it reads at a glance instead of one solid block of digits; day first
/// to match the rest of the app's date formatting (see the Profile screen's
/// date-of-birth field). Uses the moment of export/share rather than any
/// entry's own date, so it always identifies *this* file.
String exportFilenameStamp() =>
    DateFormat('dd-MM-yyyy_HH-mm').format(DateTime.now());
