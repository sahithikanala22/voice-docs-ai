import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Inspects the actual 64-bit native ELF binaries, rather than assuming that
/// ZIP alignment alone proves 16 KB runtime compatibility.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run scripts/check_android_bundle.dart path/to/app-release.aab',
    );
    exitCode = 1;
    return;
  }
  final archive = ZipDecoder().decodeBytes(
    await File(args.single).readAsBytes(),
  );
  var libraries = 0;
  var failed = false;
  for (final file in archive.files) {
    if (!file.isFile ||
        !RegExp(r'/(arm64-v8a|x86_64)/[^/]+\.so$').hasMatch(file.name)) {
      continue;
    }
    libraries++;
    final bytes = file.content;
    final result = validateElf64(bytes);
    stdout.writeln(
      '${result == null ? 'PASS' : 'FAIL'} ${file.name}${result == null ? '' : ': $result'}',
    );
    failed |= result != null;
  }
  if (libraries == 0) {
    stderr.writeln(
      'No 64-bit native libraries found; this is not a valid app release candidate.',
    );
    failed = true;
  }
  if (archive.files.any((f) => f.name.endsWith('kernel_blob.bin'))) {
    stderr.writeln('A debug Dart kernel was found in the bundle.');
    failed = true;
  }
  if (failed) exitCode = 1;
  stdout.writeln(
    'This checks ELF alignment only. Also test Play-generated APKs on a 16 KB device and run the Play pre-launch report.',
  );
}

String? validateElf64(Uint8List bytes) {
  if (bytes.length < 64 ||
      bytes[0] != 0x7f ||
      bytes[1] != 69 ||
      bytes[2] != 76 ||
      bytes[3] != 70 ||
      bytes[4] != 2) {
    return 'Invalid ELF64 header';
  }
  final endian = bytes[5] == 1 ? Endian.little : Endian.big;
  final data = ByteData.sublistView(bytes);
  final offset = data.getUint64(32, endian);
  final entrySize = data.getUint16(54, endian);
  final count = data.getUint16(56, endian);
  if (entrySize < 56 ||
      count == 0 ||
      offset + entrySize * count > bytes.length) {
    return 'Invalid program headers';
  }
  var loadSegments = 0;
  for (var i = 0; i < count; i++) {
    final start = offset + i * entrySize;
    if (data.getUint32(start, endian) != 1) continue;
    loadSegments++;
    final alignment = data.getUint64(start + 48, endian);
    if (alignment < 16384 || alignment & (alignment - 1) != 0) {
      return 'LOAD segment alignment is $alignment; requires a power of two >=16384';
    }
    final fileOffset = data.getUint64(start + 8, endian);
    final address = data.getUint64(start + 16, endian);
    if (fileOffset % 16384 != address % 16384) {
      return 'LOAD segment offset/address mismatch';
    }
  }
  return loadSegments == 0 ? 'No LOAD segments' : null;
}
