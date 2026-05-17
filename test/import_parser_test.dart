import 'package:flutter_test/flutter_test.dart';

import 'package:picklist_app/src/data/import_parser.dart';
import 'package:picklist_app/src/data/picklist_repository.dart' as repo;

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

  test('flags duplicate teams in file preview', () {
    final preview = previewCsvImport(
      'teams.csv',
      'teamNumber,nickname,auto\n4414,TideScout,87\n4414,TideScout 2,88',
    );

    expect(preview.rows, hasLength(2));
    expect(preview.issues, isNotEmpty);
    expect(preview.issues.any((issue) => issue.contains('duplicate team number 4414')), isTrue);
  });

  test('flags teams already in workspace during review', () {
    final preview = ImportPreview(
      fileName: 'teams.csv',
      rows: [
        repo.ImportedTeamRow(teamNumber: 4414, nickname: 'TideScout', metrics: const {}),
        repo.ImportedTeamRow(teamNumber: 254, nickname: 'Cheesy Poofs', metrics: const {}),
      ],
      issues: const [],
    );

    final reviewed = reviewImportAgainstWorkspace(preview, [254]);

    expect(reviewed.issues.any((issue) => issue.contains('Team 254 already exists')), isTrue);
  });
}
