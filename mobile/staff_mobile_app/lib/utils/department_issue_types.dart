const Map<String, List<String>> departmentIssueTypes = {
  'Business Permit and Licensing Division': [
    'Business Permit Application',
    'Business Permit Renewal',
    'Licensing Concern',
    'Business Inspection',
    'Permit Release Delay',
  ],
  'City Agriculturist Office': [
    'Agriculture Assistance',
    'Farmer Support',
    'Crop Damage',
    'Livestock Concern',
    'Urban Gardening',
  ],
  "City Assessor's Office": [
    'Property Assessment',
    'Tax Declaration',
    'Real Property Record',
    'Assessment Correction',
    'Property Valuation',
  ],
  "City Civil Registrar's Office": [
    'Birth Certificate',
    'Marriage Certificate',
    'Death Certificate',
    'Civil Registry Correction',
    'Delayed Registration',
  ],
  'City Disaster Risk Reduction and Management Office': [
    'Emergency Response',
    'Flooding',
    'Disaster Preparedness',
    'Hazard Report',
    'Rescue Assistance',
  ],
  "City Engineer's Office": [
    'Road Damage',
    'Drainage',
    'Street Light',
    'Sidewalk',
    'Public Works',
  ],
  'City Health Office': [
    'Public Health',
    'Sanitation',
    'Medical Assistance',
    'Health Center Concern',
    'Disease Prevention',
  ],
  "City Mayor's Office": [
    'Executive Assistance',
    'Public Service Request',
    'City Program Concern',
    'Administrative Complaint',
    'General City Concern',
  ],
  'City Social Welfare and Development Office': [
    'Social Assistance',
    'Family Welfare',
    'Senior Citizen Assistance',
    'PWD Assistance',
    'Child Welfare',
  ],
  'City Tourism Operations Office': [
    'Tourism Facility',
    'Visitor Assistance',
    'Tourism Event',
    'Heritage Site Concern',
    'Promotion Request',
  ],
  "City Treasurer's Office": [
    'Payment Concern',
    'Receipt Concern',
    'Business Tax',
    'Real Property Tax',
    'Collection Issue',
  ],
  'Land Transportation Office': [
    'Driver Licensing',
    'Vehicle Registration',
    'Road Safety',
    'Transport Regulation',
    'Traffic Violation Concern',
  ],
  'TOMECO (Traffic Operation)': [
    'Traffic Congestion',
    'Illegal Parking',
    'Traffic Signal',
    'Traffic Enforcement',
    'Road Obstruction',
  ],
};

String normalizeIssueTypeKey(String value) => value.trim().toLowerCase();

List<String> issueTypesForDepartment(String department) {
  final normalized = normalizeIssueTypeKey(department);
  for (final entry in departmentIssueTypes.entries) {
    if (normalizeIssueTypeKey(entry.key) == normalized) {
      return entry.value;
    }
  }
  return const [];
}

List<String> issueTypesForDepartments(Iterable<String> departments) {
  final values = <String, String>{};
  for (final department in departments) {
    for (final issueType in issueTypesForDepartment(department)) {
      values.putIfAbsent(normalizeIssueTypeKey(issueType), () => issueType);
    }
  }
  final items = values.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return items;
}
