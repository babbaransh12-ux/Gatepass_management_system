class LeaveRequest {

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

  LeaveRequest({
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
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      studentName: json['student_name'],
      studentId: json['student_id'],
      reason: json['reason'],
      destination: json['destination'],
      date: json['date'],
      duration: json['duration'],
      parentName: json['parent_name'],
      parentPhone: json['parent_phone'],
      studentImage: json['student_image'],
      status: json['status'],
    );
  }

}

class ParentContact {
  final String name;
  final String phone;
  final String relation;

  ParentContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  factory ParentContact.fromJson(Map<String, dynamic> json) {
    return ParentContact(
      name: json['name'] ?? 'Parent',
      phone: json['Phone'] ?? '',
      relation: json['Relation'] ?? 'Guardian',
    );
  }
}

class StudentProfile {
  final String id;
  final String name;
  final String? profileUrl;
  final List<ParentContact> parents;
  final String? roomNo;
  final String? phone;
  final String? email;
  final String? department;
  final String? course;
  
  // 🚀 Security & History Fields
  final int? activeReqId;
  final String? cooldownEndTime;
  final int cooldownRemainingMs;
  final List<Map<String, dynamic>> history;

  StudentProfile({
    required this.id,
    required this.name,
    this.profileUrl,
    required this.parents,
    this.roomNo,
    this.phone,
    this.email,
    this.department,
    this.course,
    this.activeReqId,
    this.cooldownEndTime,
    this.cooldownRemainingMs = 0,
    this.history = const [],
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      profileUrl: json['profile_url'],
      parents: (json['parents'] as List<dynamic>?)
              ?.map((e) => ParentContact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      roomNo: json['Room_no']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      department: json['department']?.toString(),
      course: json['course']?.toString(),
      activeReqId: json['active_req_id'],
      cooldownEndTime: json['cooldown_end_time'],
      cooldownRemainingMs: json['cooldown_remaining_ms'] ?? 0,
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}