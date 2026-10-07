import 'dart:io';

import 'package:boctrust_savings_loan/module/core_banking/service/scan_image_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('scan_image_file'));
  tearDown(() => dir.deleteSync(recursive: true));

  File photo(String name) => File('${dir.path}/$name')..writeAsStringSync('x');

  test('a new image deletes the previous one and clear deletes the last', () {
    final first = photo('first.jpg');
    final second = photo('second.jpg');
    final image = ScanImageFile();

    image.replace(first.path);
    image.replace(second.path);
    expect(first.existsSync(), isFalse);
    expect(second.existsSync(), isTrue);

    image.clear();
    expect(second.existsSync(), isFalse);
  });

  test('a file that is already gone is ignored', () {
    final image = ScanImageFile()..replace(photo('a.jpg').path);
    File(image.path!).deleteSync();
    expect(() => image.replace(photo('b.jpg').path), returnsNormally);

    File(image.path!).deleteSync();
    expect(image.clear, returnsNormally);
  });
}
