class OrganizationTerminology {
  static bool usesBankLabels(String? organizationName) {
    final normalized = (organizationName ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized == 'aashritha technology pvt ltd';
  }
}
