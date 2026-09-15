class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.status,
    this.category,
    this.bankName,
    this.branchName,
    this.description,
    this.expenseDate,
    this.createdAt,
    this.adminRemarks,
    this.userName,
    this.userEmail,
    this.organizationName,
    this.reviewedByName,
    this.reviewedAt,
    this.tasks = const [],
  });

  final int id;
  final String title;
  final double amount;
  final String status;
  final String? category;
  final String? bankName;
  final String? branchName;
  final String? description;
  final DateTime? expenseDate;
  final DateTime? createdAt;
  final String? adminRemarks;
  final String? userName;
  final String? userEmail;
  final String? organizationName;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final List<ExpenseTaskRef> tasks;

  String get bankNames => bankName?.trim().isNotEmpty == true
      ? bankName!
      : _distinctTaskValues((task) => task.bankName);
  String get branchNames => branchName?.trim().isNotEmpty == true
      ? branchName!
      : _distinctTaskValues((task) => task.branchName);

  String _distinctTaskValues(String? Function(ExpenseTaskRef task) valueOf) {
    final values = tasks
        .map(valueOf)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    return values.isEmpty ? '-' : values.join(', ');
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? json['user'] as Map : null;
    final organization =
        json['organization'] is Map ? json['organization'] as Map : null;
    final reviewedBy =
        json['reviewedBy'] is Map ? json['reviewedBy'] as Map : null;

    return Expense(
      id: int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] ?? '').toString(),
      amount: double.tryParse('${json['amount']}') ?? 0,
      status: (json['status'] ?? 'pending').toString(),
      category: json['category']?.toString(),
      bankName: json['bankName']?.toString(),
      branchName: json['branchName']?.toString(),
      description: json['description']?.toString(),
      expenseDate: _date(json['expenseDate']),
      createdAt: _date(json['createdat'] ?? json['createdAt']),
      adminRemarks: json['adminRemarks']?.toString(),
      userName: user?['name']?.toString(),
      userEmail: user?['email']?.toString(),
      organizationName: organization?['name']?.toString(),
      reviewedByName: reviewedBy?['name']?.toString(),
      reviewedAt: _date(json['reviewedat'] ?? json['reviewedAt']),
      tasks: _tasks(json['taskMaps']),
    );
  }

  static List<ExpenseTaskRef> _tasks(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) {
      final task = item['task'] is Map ? item['task'] as Map : item;
      return ExpenseTaskRef.fromJson(Map<String, dynamic>.from(task));
    }).toList();
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse('$value')?.toLocal();
  }
}

class ExpenseTaskRef {
  const ExpenseTaskRef({
    required this.id,
    required this.title,
    this.status,
    this.bankName,
    this.branchName,
  });

  final int id;
  final String title;
  final String? status;
  final String? bankName;
  final String? branchName;

  factory ExpenseTaskRef.fromJson(Map<String, dynamic> json) {
    return ExpenseTaskRef(
      id: int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] ?? 'Ticket #${json['id'] ?? ''}').toString(),
      status: json['status'] is Map
          ? json['status']['name']?.toString()
          : json['status']?.toString(),
      bankName:
          json['category'] is Map ? json['category']['name']?.toString() : null,
      branchName: json['branchName']?.toString(),
    );
  }
}
