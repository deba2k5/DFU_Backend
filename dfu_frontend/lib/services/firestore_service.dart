import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class BackendConfig {
  // Single backend — Vercel handles everything: /predict, /reports, /health, /chat
  // onnxruntime + ONNX model are bundled in the Vercel lambda (50MB limit)
  static const String baseUrl = 'https://dfubackend.vercel.app';
  static const String predictUrl = 'https://dfubackend.vercel.app';
}



class DFUReport {
  final String id;
  final String fileNo;
  final String userId;
  final String userName;
  final String userEmail;
  final int stage;
  final String condition;
  final double confidence;
  final String clinicalReport;
  final String aiInsights;
  final String imagePath;
  final String pdfUrl;
  final Map<String, dynamic> patient;
  final DateTime timestamp;

  DFUReport({
    required this.id,
    required this.fileNo,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.stage,
    required this.condition,
    required this.confidence,
    required this.clinicalReport,
    required this.aiInsights,
    required this.imagePath,
    required this.pdfUrl,
    required this.patient,
    required this.timestamp,
  });

  factory DFUReport.fromMap(Map<String, dynamic> map, String id) {
    final patient = Map<String, dynamic>.from(map['patient'] ?? {});
    return DFUReport(
      id: id,
      fileNo: map['file_no']?.toString() ?? patient['fileNo']?.toString() ?? '',
      userId: patient['mobile']?.toString() ?? '',
      userName:
          patient['name']?.toString() ?? map['userName']?.toString() ?? '',
      userEmail: '',
      stage: int.tryParse(map['stage']?.toString() ?? '0') ?? 0,
      condition: map['condition']?.toString() ?? '',
      confidence: double.tryParse(map['confidence']?.toString() ?? '0') ?? 0,
      clinicalReport:
          map['clinical_report']?.toString() ??
          map['clinicalReport']?.toString() ??
          '',
      aiInsights:
          map['ai_insights']?.toString() ?? map['aiInsights']?.toString() ?? '',
      imagePath:
          map['image_path']?.toString() ?? map['imagePath']?.toString() ?? '',
      pdfUrl: map['pdf_url']?.toString() ?? '',
      patient: patient,
      timestamp:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() => _instance;

  FirestoreService._internal() {
    _connectSocket();
    refreshReports();
  }

  final StreamController<List<DFUReport>> _reportsController =
      StreamController<List<DFUReport>>.broadcast();
  final List<DFUReport> _reports = [];
  io.Socket? _socket;

  void _connectSocket() {
    _socket = io.io(
      BackendConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io')
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect(
        (_) => _socket!.emit('join_doctor_portal', {'role': 'doctor'}),
      )
      ..on('doctor_pdf_report', (data) {
        if (data is Map) {
          final report = DFUReport.fromMap(
            Map<String, dynamic>.from(data),
            data['id']?.toString() ?? '',
          );
          _reports.removeWhere((item) => item.id == report.id);
          _reports.insert(0, report);
          _reportsController.add(List.unmodifiable(_reports));
        }
      })
      ..connect();
  }

  Future<void> refreshReports({int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.baseUrl}/reports?limit=$limit'),
      );
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final reports = (body['reports'] as List<dynamic>? ?? [])
          .map(
            (item) => DFUReport.fromMap(
              Map<String, dynamic>.from(item),
              item['id']?.toString() ?? '',
            ),
          )
          .toList();
      _reports
        ..clear()
        ..addAll(reports);
      _reportsController.add(List.unmodifiable(_reports));
    } catch (_) {
      _reportsController.add(List.unmodifiable(_reports));
    }
  }

  Future<Map<String, dynamic>> saveDetailedDFUReport({
    required Map<String, dynamic> patient,
    required Map<String, dynamic> medicalHistory,
    required Map<String, dynamic> diabeticFootHistory,
    required Map<String, dynamic> examination,
    required Map<String, dynamic> prediction,
    required String clinicalReport,
    required String aiInsights,
    required String imagePath,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${BackendConfig.baseUrl}/reports'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient': patient,
          'medical_history': medicalHistory,
          'diabetic_foot_history': diabeticFootHistory,
          'examination': examination,
          'prediction': prediction,
          'clinical_report': clinicalReport,
          'ai_insights': aiInsights,
          'image_path': imagePath,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timed out after 30s'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await refreshReports();
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      // Try to extract the detailed error message from backend
      String detail = 'Unknown error';
      try {
        final errBody = jsonDecode(response.body);
        detail = errBody['detail']?.toString() ?? errBody.toString();
      } catch (_) {
        detail = response.body;
      }
      throw Exception('Backend report save failed (${response.statusCode}): $detail');
    } catch (e) {
      rethrow;
    }
  }


  Future<void> saveDFUReport({
    required String userName,
    required int stage,
    required String condition,
    required double confidence,
    required String clinicalReport,
    required String aiInsights,
    required String imagePath,
  }) {
    return saveDFUReportAsync(
      userName: userName,
      stage: stage,
      condition: condition,
      confidence: confidence,
      clinicalReport: clinicalReport,
      aiInsights: aiInsights,
      imagePath: imagePath,
    );
  }

  Future<void> saveDFUReportAsync({
    required String userName,
    required int stage,
    required String condition,
    required double confidence,
    required String clinicalReport,
    required String aiInsights,
    required String imagePath,
  }) async {
    await saveDetailedDFUReport(
      patient: {
        'name': userName,
        'fileNo': '',
        'date': DateTime.now().toIso8601String().split('T').first,
      },
      medicalHistory: {},
      diabeticFootHistory: {},
      examination: {},
      prediction: {
        'condition': condition,
        'confidence': confidence,
        'stage': stage,
      },
      clinicalReport: clinicalReport,
      aiInsights: aiInsights,
      imagePath: imagePath,
    );
  }

  Future<List<DFUReport>> searchReportsByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return [];
    final response = await http.get(
      Uri.parse(
        '${BackendConfig.baseUrl}/reports/search?name=${Uri.encodeQueryComponent(trimmed)}',
      ),
    );
    if (response.statusCode != 200) {
      String detail = 'Search failed';
      try {
        final errBody = jsonDecode(response.body);
        detail = errBody['detail']?.toString() ?? errBody.toString();
      } catch (_) {}
      throw Exception(detail);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['reports'] as List<dynamic>? ?? [])
        .map(
          (item) => DFUReport.fromMap(
            Map<String, dynamic>.from(item),
            item['id']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Stream<List<DFUReport>> getUserReportsStream() => getAllReportsStream();

  Stream<List<DFUReport>> getAllReportsStream() {
    refreshReports();
    return _reportsController.stream;
  }

  Stream<List<DFUReport>> getReportsByStageStream(int stage) {
    return getAllReportsStream().map(
      (reports) => reports.where((report) => report.stage == stage).toList(),
    );
  }

  Stream<List<DFUReport>> getRecentScans({int limit = 10, dynamic startAfter}) {
    refreshReports(limit: limit);
    return _reportsController.stream.map(
      (reports) => reports.take(limit).toList(),
    );
  }

  Future<DFUReport?> getLatestReport() async {
    await refreshReports(limit: 1);
    return _reports.isEmpty ? null : _reports.first;
  }

  Future<void> deleteReport(String reportId) async {
    _reports.removeWhere((report) => report.id == reportId);
    _reportsController.add(List.unmodifiable(_reports));
  }
}
