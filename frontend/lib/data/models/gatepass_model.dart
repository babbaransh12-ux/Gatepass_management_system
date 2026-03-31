class GatepassModel {

  final String id;
  final String studentId;
  final int scanCount;
  final String status;

  GatepassModel({
    required this.id,
    required this.studentId,
    required this.scanCount,
    required this.status,
  });

  factory GatepassModel.fromJson(Map<String, dynamic> json) {

    return GatepassModel(
      id: json['id'],
      studentId: json['student_id'],
      scanCount: json['scan_count'],
      status: json['status'],
    );

  }

}