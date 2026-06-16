import 'package:flutter_test/flutter_test.dart';
import 'package:dfu_app/main.dart';

void main() {
  test('app root widget is available', () {
    expect(const DFUApp(), isA<DFUApp>());
  });
}
