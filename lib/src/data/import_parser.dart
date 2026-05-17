import 'dart:convert';

import 'package:csv/csv.dart';

import 'picklist_repository.dart';

class ImportPreview {
  const ImportPreview({
    required this.fileName,
    required this.rows,
    required this.issues,
  });

  final String fileName;
  final List<ImportedTeamRow> rows;
  final List<String> issues;

  bool get hasIssues => issues.isNotEmpty;
}

List<ImportedTeamRow> parseCsvImport(String content) {
  final rows = const CsvToListConverter().convert(content);
  if (rows.isEmpty) {
    throw FormatException('CSV file is empty.');
  }
  final headers = rows.first.map((value) => value.toString().trim().toLowerCase()).toList();
  final teamNumberIndex = headers.indexOf('teamnumber');
  final nicknameIndex = headers.indexOf('nickname');
  if (teamNumberIndex == -1 || nicknameIndex == -1) {
    throw FormatException('CSV must include teamNumber and nickname columns.');
  }
  return rows.skip(1).where((row) => row.isNotEmpty).map((row) {
    final teamNumber = int.parse(row[teamNumberIndex].toString());
    final nickname = row[nicknameIndex].toString();
    final metrics = <String, double>{};
    for (var i = 0; i < headers.length; i++) {
      if (i == teamNumberIndex || i == nicknameIndex) continue;
      final value = double.tryParse(row[i].toString());
      if (value != null) {
        metrics[headers[i]] = value;
      }
    }
    return ImportedTeamRow(teamNumber: teamNumber, nickname: nickname, metrics: metrics);
  }).toList(growable: false);
}

ImportPreview previewCsvImport(String fileName, String content) {
  final rows = const CsvToListConverter().convert(content);
  if (rows.isEmpty) {
    throw FormatException('CSV file is empty.');
  }
  final headers = rows.first.map((value) => value.toString().trim().toLowerCase()).toList();
  final teamNumberIndex = headers.indexOf('teamnumber');
  final nicknameIndex = headers.indexOf('nickname');
  if (teamNumberIndex == -1 || nicknameIndex == -1) {
    throw FormatException('CSV must include teamNumber and nickname columns.');
  }
  final issues = <String>[];
  final seenTeams = <int>{};
  final importedRows = <ImportedTeamRow>[];
  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    if (row.isEmpty) {
      continue;
    }
    try {
      final teamNumber = int.parse(row[teamNumberIndex].toString());
      final nickname = row[nicknameIndex].toString().trim();
      if (nickname.isEmpty) {
        issues.add('Row ${rowIndex + 1}: nickname is blank.');
        continue;
      }
      if (!seenTeams.add(teamNumber)) {
        issues.add('Row ${rowIndex + 1}: duplicate team number $teamNumber in file.');
      }
      final metrics = <String, double>{};
      for (var i = 0; i < headers.length; i++) {
        if (i == teamNumberIndex || i == nicknameIndex) continue;
        final value = double.tryParse(row[i].toString());
        if (value != null) {
          metrics[headers[i]] = value;
        }
      }
      importedRows.add(ImportedTeamRow(teamNumber: teamNumber, nickname: nickname, metrics: metrics));
    } on FormatException catch (error) {
      issues.add('Row ${rowIndex + 1}: ${error.message}');
    } on RangeError {
      issues.add('Row ${rowIndex + 1}: missing required values.');
    }
  }
  return ImportPreview(fileName: fileName, rows: importedRows, issues: issues);
}

List<ImportedTeamRow> parseJsonImport(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! List) {
    throw FormatException('JSON import must be an array of team objects.');
  }
  return decoded.map((entry) {
    if (entry is! Map<String, dynamic>) {
      throw FormatException('Each JSON row must be an object.');
    }
    final teamNumber = entry['teamNumber'];
    final nickname = entry['nickname'];
    if (teamNumber == null || nickname == null) {
      throw FormatException('Each JSON row requires teamNumber and nickname.');
    }
    final metrics = <String, double>{};
    final rawMetrics = entry['metrics'];
    if (rawMetrics is Map<String, dynamic>) {
      for (final metricEntry in rawMetrics.entries) {
        final value = metricEntry.value;
        if (value is num) {
          metrics[metricEntry.key] = value.toDouble();
        }
      }
    }
    return ImportedTeamRow(
      teamNumber: int.parse(teamNumber.toString()),
      nickname: nickname.toString(),
      metrics: metrics,
    );
  }).toList(growable: false);
}

ImportPreview previewJsonImport(String fileName, String content) {
  final decoded = jsonDecode(content);
  if (decoded is! List) {
    throw FormatException('JSON import must be an array of team objects.');
  }
  final issues = <String>[];
  final seenTeams = <int>{};
  final rows = <ImportedTeamRow>[];
  for (var index = 0; index < decoded.length; index++) {
    final entry = decoded[index];
    if (entry is! Map<String, dynamic>) {
      issues.add('Row ${index + 1}: each JSON row must be an object.');
      continue;
    }
    final teamNumber = entry['teamNumber'];
    final nickname = entry['nickname'];
    if (teamNumber == null || nickname == null) {
      issues.add('Row ${index + 1}: teamNumber and nickname are required.');
      continue;
    }
    final parsedTeamNumber = int.tryParse(teamNumber.toString());
    if (parsedTeamNumber == null) {
      issues.add('Row ${index + 1}: teamNumber must be numeric.');
      continue;
    }
    final parsedNickname = nickname.toString().trim();
    if (parsedNickname.isEmpty) {
      issues.add('Row ${index + 1}: nickname is blank.');
      continue;
    }
    if (!seenTeams.add(parsedTeamNumber)) {
      issues.add('Row ${index + 1}: duplicate team number $parsedTeamNumber in file.');
    }
    final metrics = <String, double>{};
    final rawMetrics = entry['metrics'];
    if (rawMetrics is Map<String, dynamic>) {
      for (final metricEntry in rawMetrics.entries) {
        final value = metricEntry.value;
        if (value is num) {
          metrics[metricEntry.key] = value.toDouble();
        }
      }
    }
    rows.add(ImportedTeamRow(teamNumber: parsedTeamNumber, nickname: parsedNickname, metrics: metrics));
  }
  return ImportPreview(fileName: fileName, rows: rows, issues: issues);
}
