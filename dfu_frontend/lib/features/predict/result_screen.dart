import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/glass_widgets.dart';
import '../../core/theme.dart';
import '../../services/firestore_service.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSaving = false;
  bool _saved = false;
  bool _autoSaveStarted = false;
  String? _pdfUrl;

  Future<void> _saveDetailedReport({
    required Map<String, dynamic> intake,
    required Map<String, dynamic> prediction,
    required String clinicalReport,
    required String aiInsights,
    required String imagePath,
  }) async {
    if (_isSaving || _saved) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final result = await FirestoreService().saveDetailedDFUReport(
        patient: Map<String, dynamic>.from(intake['patient'] ?? {}),
        medicalHistory: Map<String, dynamic>.from(
          intake['medicalHistory'] ?? {},
        ),
        diabeticFootHistory: Map<String, dynamic>.from(
          intake['diabeticFootHistory'] ?? {},
        ),
        examination: Map<String, dynamic>.from(intake['examination'] ?? {}),
        prediction: prediction,
        clinicalReport: clinicalReport,
        aiInsights: aiInsights,
        imagePath: imagePath,
      );

      final pdfUrl = result['pdf_url']?.toString();
      if (!mounted) {
        return;
      }
      setState(() {
        _saved = true;
        _isSaving = false;
        _pdfUrl = pdfUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report saved and PDF generated.'),
          backgroundColor: AppTheme.mintGreen,
          duration: Duration(seconds: 2),
        ),
      );

      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        await launchUrl(
          Uri.parse(pdfUrl),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? imagePath = args?['imagePath'];
    // backend returns: {"success": true, "prediction": {...}, "clinical_report": "...", "ai_insights": "..."}
    final Map<String, dynamic>? data = args?['prediction'];
    final Map<String, dynamic>? prediction = data?['prediction'];
    final Map<String, dynamic> intake = Map<String, dynamic>.from(
      args?['intake'] ?? {},
    );
    final dynamic clinicalReportRaw = data?['clinical_report'];
    String clinicalReport = "";
    if (clinicalReportRaw is String) {
      clinicalReport = clinicalReportRaw;
    } else if (clinicalReportRaw is Map) {
      clinicalReport = clinicalReportRaw['primary_note']?.toString() ?? "";
    } else {
      clinicalReport = clinicalReportRaw?.toString() ?? "";
    }

    final String aiInsights = data?['ai_insights']?.toString() ?? "";

    String rawCondition =
        prediction?['condition']?.toString() ?? "Unknown Diagnostic";
    String rawConfidence = prediction?['confidence']?.toString() ?? "0.0";

    int stage = 0;
    if (rawCondition.toLowerCase().contains("extensive gangrene")) {
      stage = 5;
    } else if (rawCondition.toLowerCase().contains("localized gangrene")) {
      stage = 4;
    } else if (rawCondition.toLowerCase().contains("osteomyelitis") ||
        rawCondition.toLowerCase().contains("grade 3")) {
      stage = 3;
    } else if (rawCondition.toLowerCase().contains("deep ulcer") ||
        rawCondition.toLowerCase().contains("grade 2")) {
      stage = 2;
    } else if (rawCondition.toLowerCase().contains("surface ulcer") ||
        rawCondition.toLowerCase().contains("grade 1")) {
      stage = 1;
    } else if (rawCondition.toLowerCase().contains("healthy") ||
        rawCondition.toLowerCase().contains("grade 0")) {
      stage = 0;
    } else {
      // Fallback: try to extract number from condition string if it says "Grade X"
      final match = RegExp(
        r'grade\s*(\d)',
        caseSensitive: false,
      ).firstMatch(rawCondition);
      if (match != null) {
        stage = int.tryParse(match.group(1) ?? "0") ?? 0;
      }
    }

    double conf = double.tryParse(rawConfidence) ?? 0.89;

    final severityColor = _getSeverityColor(stage);
    if (!_autoSaveStarted && prediction != null && intake.isNotEmpty) {
      _autoSaveStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveDetailedReport(
          intake: intake,
          prediction: Map<String, dynamic>.from(prediction),
          clinicalReport: clinicalReport,
          aiInsights: aiInsights,
          imagePath: imagePath ?? '',
        );
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF0F172A), Color(0xFF0B0E14)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 30),
                  _buildImagePreview(imagePath),
                  const SizedBox(height: 20),
                  _buildPatientCard(intake),
                  const SizedBox(height: 30),
                  _buildResultsCard(
                    severityColor,
                    rawCondition.toUpperCase(),
                    conf,
                    stage,
                    context,
                  ),
                  const SizedBox(height: 20),
                  _buildAIGroqCard(aiInsights),
                  const SizedBox(height: 20),
                  _buildReportCard(clinicalReport),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          text: _saved
                              ? 'PDF READY'
                              : (_isSaving ? 'SAVING...' : 'SAVE + PDF'),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  if (_saved && _pdfUrl != null) {
                                    launchUrl(
                                      Uri.parse(_pdfUrl!),
                                      mode: LaunchMode.externalApplication,
                                      webOnlyWindowName: '_blank',
                                    );
                                    return;
                                  }
                                  _saveDetailedReport(
                                    intake: intake,
                                    prediction: Map<String, dynamic>.from(
                                      prediction ?? {},
                                    ),
                                    clinicalReport: clinicalReport,
                                    aiInsights: aiInsights,
                                    imagePath: imagePath ?? '',
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildSecondaryButton(
                          _pdfUrl == null ? 'DASHBOARD' : 'OPEN PDF',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryCyan, width: 1),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryCyan, AppTheme.mintGreen],
                          ),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI ANALYSIS RESULT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.more_vert, color: Colors.white),
      ],
    );
  }

  Widget _buildImagePreview(String? imagePath) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white10),
        image: imagePath != null
            ? DecorationImage(
                image: NetworkImage(
                  imagePath,
                ), // NetworkImage works for both blob URLs (web) and http URLs
                fit: BoxFit.contain,
              )
            : const DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1576091160550-217359f49f4c?auto=format&fit=crop&q=80&w=400',
                ),
                fit: BoxFit.contain,
              ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.zoom_in, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> intake) {
    final patient = Map<String, dynamic>.from(intake['patient'] ?? {});
    return GlassCard(
      borderRadius: 8,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PATIENT DETAILS',
            style: TextStyle(
              color: AppTheme.primaryCyan,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${patient['name'] ?? 'Patient'}  •  File ${patient['fileNo'] ?? ''}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Age ${patient['age'] ?? ''} | ${patient['sex'] ?? ''} | ${patient['mobile'] ?? ''}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard(
    Color severityColor,
    String conditionText,
    double confidence,
    int stage,
    BuildContext context,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI SCREENING OUTPUT',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      conditionText,
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: severityColor,
                  size: 30,
                ),
              ),
            ],
          ),
          const Divider(height: 40, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('Confidence', '${(confidence * 100).toInt()}%'),
              _buildMetric('Model', 'ONNX Model'),
              _buildMetric('Grade', 'Wagner $stage'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildAIGroqCard(String insights) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.psychology,
                color: Colors.purpleAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'GROQ AI INSIGHTS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            insights.isNotEmpty ? insights : "Generating cognitive summary...",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(String report) {
    return GlassCard(
      opacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLINICAL RECOMMENDATIONS',
            style: TextStyle(
              color: AppTheme.primaryCyan,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            report.isNotEmpty
                ? report
                : "Observation required. Schedule follow-up scan in 48 hours.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryButton(String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextButton(
        onPressed: () async {
          if (_pdfUrl != null) {
            await launchUrl(
              Uri.parse(_pdfUrl!),
              mode: LaunchMode.externalApplication,
              webOnlyWindowName: '_blank',
            );
          } else {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        },
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(int stage) {
    switch (stage) {
      case 0:
        return AppTheme.mintGreen;
      case 1:
        return Colors.yellowAccent;
      case 2:
        return Colors.orangeAccent;
      case 3:
        return Colors.redAccent;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.deepPurpleAccent;
      default:
        return Colors.blueAccent;
    }
  }
}
