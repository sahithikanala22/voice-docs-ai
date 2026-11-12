import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../scripts/check_android_bundle.dart' show validateElf64;

Uint8List elf(int alignment, {int address = 0}) {
  final bytes = Uint8List(120);
  bytes.setAll(0, [0x7f, 69, 76, 70, 2, 1]);
  final data = ByteData.sublistView(bytes);
  data.setUint64(32, 64, Endian.little);
  data.setUint16(54, 56, Endian.little);
  data.setUint16(56, 1, Endian.little);
  data.setUint32(64, 1, Endian.little);
  data.setUint64(64 + 16, address, Endian.little);
  data.setUint64(64 + 48, alignment, Endian.little);
  return bytes;
}

void main() {
  test(
    'ELF check rejects 4 KB segments even when APK ZIP could be aligned',
    () {
      expect(validateElf64(elf(4096)), contains('requires'));
      expect(validateElf64(elf(16384)), isNull);
      expect(validateElf64(elf(65536)), isNull);
    },
  );
  test('ELF check rejects malformed and incongruent native load segments', () {
    expect(validateElf64(Uint8List(8)), contains('Invalid'));
    expect(validateElf64(elf(16384, address: 4096)), contains('mismatch'));
  });
}
