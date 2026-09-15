class Bank {
  const Bank({
    required this.id,
    required this.name,
    this.description,
    this.branchName,
    this.branchCode,
    this.address,
    this.phoneNumber,
  });

  final int id;
  final String name;
  final String? description;
  final String? branchName;
  final String? branchCode;
  final String? address;
  final String? phoneNumber;

  String get displayName => name;

  factory Bank.fromJson(Map<String, dynamic> json) => Bank(
        id: int.tryParse('${json['id']}') ?? 0,
        name: (json['name'] ?? json['categoryName'] ?? '').toString(),
        description: json['description']?.toString(),
        branchName: json['branchName']?.toString(),
        branchCode: json['branchCode']?.toString(),
        address: json['address']?.toString(),
        phoneNumber: (json['phoneNumber'] ?? json['contactNumber'])?.toString(),
      );
}
