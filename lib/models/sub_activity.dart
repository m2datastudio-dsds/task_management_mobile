import 'dart:convert';

class SubActivity {
  const SubActivity({
    required this.id,
    required this.taskId,
    required this.title,
    required this.status,
    required this.createdBy,
    this.remarks,
  });

  final int id;
  final int taskId;
  final String title;
  final String status;
  final String? remarks;
  final int createdBy;

  bool get isTableFormat => tableColumns.isNotEmpty && tableCells.isNotEmpty;

  List<String> get tableColumns {
    final meta = _metadata;
    final columns = meta?['columns'];
    if (columns is List) return columns.map((item) => '$item').toList();
    return const [];
  }

  List<String> get tableCells {
    final meta = _metadata;
    final cells = meta?['cells'];
    if (cells is List) return cells.map((item) => '$item').toList();
    return const [];
  }

  String? get displayRemarks {
    if (isTableFormat) return null;
    return remarks;
  }

  Map<String, dynamic>? get _metadata {
    final value = remarks;
    if (value == null || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic> &&
          decoded['subActivityFormat'] == 'table') {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String tableRemarksFor(List<String> cells) {
    return jsonEncode({
      'subActivityFormat': 'table',
      'columns': tableColumns,
      'cells': cells,
    });
  }

  factory SubActivity.fromJson(Map<String, dynamic> json) => SubActivity(
        id: int.tryParse('${json['id']}') ?? 0,
        taskId: int.tryParse('${json['taskid']}') ?? 0,
        title: (json['title'] ?? '').toString(),
        status: (json['status'] ?? 'pending').toString(),
        remarks: json['remarks']?.toString(),
        createdBy: int.tryParse('${json['createdby']}') ?? 0,
      );
}
