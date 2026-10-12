import 'package:cloud_firestore/cloud_firestore.dart';

enum WarningSeverity { low, moderate, high, severe }

enum WarningStatus { draft, published, cancelled, expired }

WarningSeverity warningSeverityFromString(String? value) {
  return WarningSeverity.values.firstWhere(
    (item) => item.name == value,
    orElse: () => WarningSeverity.moderate,
  );
}

WarningStatus warningStatusFromString(String? value) {
  return WarningStatus.values.firstWhere(
    (item) => item.name == value,
    orElse: () => WarningStatus.draft,
  );
}

class FloodWarning {
  const FloodWarning({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.affectedArea,
    required this.issueTime,
    required this.expiryTime,
    required this.source,
    required this.status,
    required this.createdBy,
    this.isSimulation = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final WarningSeverity severity;
  final String affectedArea;
  final DateTime issueTime;
  final DateTime expiryTime;
  final String source;
  final WarningStatus status;
  final String createdBy;
  final bool isSimulation;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive =>
      status == WarningStatus.published && expiryTime.isAfter(DateTime.now());

  factory FloodWarning.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('Warning document has no data.');
    }

    DateTime readDate(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      throw FormatException('Warning field "$key" is missing or invalid.');
    }

    return FloodWarning(
      id: snapshot.id,
      title: _requiredString(data, 'title'),
      description: _requiredString(data, 'description'),
      severity: warningSeverityFromString(data['severity'] as String?),
      affectedArea: _requiredString(data, 'affectedArea'),
      issueTime: readDate('issueTime'),
      expiryTime: readDate('expiryTime'),
      source: _requiredString(data, 'source'),
      status: warningStatusFromString(data['status'] as String?),
      createdBy: _requiredString(data, 'createdBy'),
      isSimulation: data['simulation'] as bool? ?? false,
      createdAt: _optionalDate(data['createdAt']),
      updatedAt: _optionalDate(data['updatedAt']),
    );
  }

  Map<String, Object?> toFirestore() => {
    'title': title,
    'description': description,
    'severity': severity.name,
    'affectedArea': affectedArea,
    'issueTime': Timestamp.fromDate(issueTime),
    'expiryTime': Timestamp.fromDate(expiryTime),
    'source': source,
    'status': status.name,
    'createdBy': createdBy,
    'simulation': isSimulation,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Warning field "$key" is missing or invalid.');
    }
    return value;
  }

  static DateTime? _optionalDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
