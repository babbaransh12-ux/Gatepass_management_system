class LeaveRequestModel {

  final String requestId;
  final String studentName;
  final String studentId;
  final String reason;
  final String destination;
  final String date;
  final String duration;
  final String parentName;
  final String parentPhone;
  final String studentImage;
  final String status;
  final String? gender;
  final String? department;

  LeaveRequestModel({
    required this.requestId,
    required this.studentName,
    required this.studentId,
    required this.reason,
    required this.destination,
    required this.date,
    required this.duration,
    required this.parentName,
    required this.parentPhone,
    required this.studentImage,
    required this.status,
    this.gender,
    this.department,
  });

  static String _formatDuration(dynamic val) {
    if (val == null) return "0 Days";
    if (val is String) {
      if (val.isEmpty) return "0 Days";
      final numVal = double.tryParse(val);
      if (numVal == null) return val;
      val = numVal;
    }
    if (val is num) {
      if (val < 1 && val > 0) {
         int hours = (val * 24).round();
         return "$hours Hours";
      } else {
         return "${val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} Days";
      }
    }
    return val.toString();
  }

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      requestId: (json['Req_id'] ?? json['request_id'] ?? 0).toString(),
      studentName: json['student_name'] ?? 'Unknown',
      studentId: (json['AU_id']?.toString() ?? json['student_id']?.toString() ?? ''),
      reason: json['Reason'] ?? json['reason'] ?? '',
      destination: json['Destination'] ?? json['destination'] ?? '',
      date: json['leave_date'] ?? json['created_at'] ?? json['date'] ?? '',
      duration: _formatDuration(json['Days'] ?? json['duration']),
      parentName: json['parent_name'] ?? '',
      parentPhone: json['parent_phone'] ?? '',
      studentImage: json['profile_url'] ?? json['student_image'] ?? 'https://ui-avatars.com/api/?name=${json['student_name'] ?? 'Student'}',
      status: json['Status'] ?? json['status'] ?? 'Pending',
      gender: json['gender'] ?? json['Gender'],
      department: json['department'] ?? json['Department'] ?? json['Dept'],
    );
  }

}