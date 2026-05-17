import 'package:flutter_test/flutter_test.dart';

import 'package:picklist_app/src/data/import_parser.dart';

void main() {
  test('parses CSV team imports and numeric metrics', () {
    final rows = parseCsvImport('teamNumber,nickname,auto,teleop\n4414,TideScout,87,92');

    expect(rows, hasLength(1));
    expect(rows.single.teamNumber, 4414);
    expect(rows.single.nickname, 'TideScout');
    expect(rows.single.metrics['auto'], 87);
    expect(rows.single.metrics['teleop'], 92);
  });

  test('parses JSON team imports and nested metrics', () {
    final rows = parseJsonImport('[{"teamNumber":254,"nickname":"Cheesy Poofs","metrics":{"auto":95,"teleop":90}}]');

    expect(rows, hasLength(1));
    expect(rows.single.teamNumber, 254);
    expect(rows.single.nickname, 'Cheesy Poofs');
    expect(rows.single.metrics['auto'], 95);
    expect(rows.single.metrics['teleop'], 90);
  });
}
