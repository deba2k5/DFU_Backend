import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../widgets/glass_widgets.dart';
import '../../core/theme.dart';
import '../../services/firestore_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _isProcessing = false;
  XFile? _selectedXFile;

  final List<String> _patientFields = const [
    'date',
    'fileNo',
    'name',
    'age',
    'sex',
    'address',
    'mobile',
    'referringDoctor',
  ];

  final List<String> _medicalFields = const [
    'durationOfDiabetes',
    'durationOfHypertension',
    'height',
    'weight',
    'bmi',
    'dyslipidemia',
    'smoker',
    'cvd',
    'ckd',
    'bloodSugar',
    'hba1c',
  ];

  final List<String> _footHistoryBase = const [
    'durationOfUlcer',
    'pastHistoryOfUlcer',
    'historyOfAmputation',
    'jointPain',
    'stiffness',
    'drySkin',
    'numbness',
    'tinglingPricking',
    'paresthesia',
    'claudication',
    'cramping',
    'oedema',
  ];

  final List<String> _examinationFields = const [
    'inspectionDrySkin',
    'inspectionFissure',
    'inspectionDeformity',
    'inspectionCallus',
    'inspectionAbnormalShape',
    'inspectionNailLesion',
    'inspectionLossOfHair',
    'palpationRight',
    'palpationLeft',
    'footPulseDorsalisPedisRt',
    'footPulseDorsalisPedisLt',
    'footPulsePosteriorTibialisRt',
    'footPulsePosteriorTibialisLt',
    'neuropathyMonofilamentRight',
    'neuropathyMonofilamentLeft',
    'neuropathyVptRight',
    'neuropathyVptLeft',
    'neuropathyHcpRight',
    'neuropathyHcpLeft',
    'vascularDorsalisPedisRight',
    'vascularDorsalisPedisLeft',
    'vascularPosteriorTibialisRight',
    'vascularPosteriorTibialisLeft',
    'vascularBrachialisRight',
    'vascularBrachialisLeft',
    'vascularAbiRight',
    'vascularAbiLeft',
    'xrayRight',
    'xrayLeft',
    'ulcerLocation',
    'ulcerSize',
    'ulcerBase',
    'ulcerMargins',
    'ulcerDepth',
    'clinicalDiagnosisNeuropathy',
    'clinicalDiagnosisCharcotFoot',
    'clinicalDiagnosisPvd',
    'clinicalDiagnosisInfected',
    'clinicalDiagnosisOthers',
    'treatmentCallusCornRemoved',
    'treatmentNailParing',
    'treatmentIDDone',
    'treatmentPusForCs',
    'treatmentProbing',
    'treatmentExtensiveDebridement',
    'treatmentSurgicalReferral',
    'treatmentOthers',
    'offloadingSk',
    'offloadingShoe',
    'offloadingTotalContactCast',
    'offloadingInstantTcc',
    'offloadingCustomFootwear',
    'offloadingOthers',
    'followUp',
  ];

  @override
  void initState() {
    super.initState();
    for (final key in [
      ..._patientFields,
      ..._medicalFields,
      ..._footHistoryBase.expand((field) => ['${field}Right', '${field}Left']),
      ..._examinationFields,
    ]) {
      _controllers[key] = TextEditingController();
    }
    _controllers['date']!.text = DateTime.now()
        .toIso8601String()
        .split('T')
        .first;
    _controllers['fileNo']!.text = _generateFileNo();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _generateFileNo() {
    final now = DateTime.now();
    return 'ILS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';
  }

  Map<String, dynamic> _mapFrom(List<String> keys) {
    return {for (final key in keys) key: _controllers[key]?.text.trim() ?? ''};
  }

  Map<String, dynamic> _intakePayload() {
    return {
      'patient': _mapFrom(_patientFields),
      'medicalHistory': _mapFrom(_medicalFields),
      'diabeticFootHistory': {
        for (final field in _footHistoryBase)
          field: {
            'right': _controllers['${field}Right']?.text.trim() ?? '',
            'left': _controllers['${field}Left']?.text.trim() ?? '',
          },
      },
      'examination': _mapFrom(_examinationFields),
    };
  }

  Future<void> _captureAndScanImage(ImageSource source) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete patient name, age, sex, mobile, and address before scan.',
          ),
        ),
      );
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _selectedXFile = pickedFile;
        _isProcessing = true;
      });

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${BackendConfig.baseUrl}/predict'),
      );

      request.fields['patient_data'] = jsonEncode(_intakePayload());

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: pickedFile.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', pickedFile.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (response.statusCode == 200) {
        Navigator.pushReplacementNamed(
          context,
          '/results',
          arguments: {
            'imagePath': pickedFile.path,
            'prediction': jsonDecode(response.body),
            'intake': _intakePayload(),
          },
        );
      } else {
        _showError('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Failed to connect to backend: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF07131A),
                  Color(0xFF101820),
                  Color(0xFF111827),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    sliver: SliverList.list(
                      children: [
                        _section(
                          'Patient Information',
                          Icons.badge_outlined,
                          _patientFields.map(_textField).toList(),
                        ),
                        _section(
                          'Medical History',
                          Icons.monitor_heart_outlined,
                          _medicalFields.map(_textField).toList(),
                        ),
                        _footHistorySection(),
                        _section(
                          'Examination Of Foot',
                          Icons.fact_check_outlined,
                          _examinationFields.map(_textField).toList(),
                        ),
                        _scanPanel(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ILS Hospital DFU Intake',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Complete the clinical form before foot scan',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderRadius: 8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryCyan, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _footHistorySection() {
    return _section(
      'Diabetic Foot History',
      Icons.directions_walk_outlined,
      _footHistoryBase.map((field) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: _textField(
                  '${field}Right',
                  label: '${_label(field)} - RT',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  '${field}Left',
                  label: '${_label(field)} - LT',
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _textField(String key, {String? label}) {
    final required = const {
      'name',
      'age',
      'sex',
      'address',
      'mobile',
    }.contains(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _controllers[key],
        readOnly: key == 'fileNo',
        style: const TextStyle(color: Colors.white),
        validator: required
            ? (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label ?? _label(key),
          labelStyle: const TextStyle(color: Colors.white60),
          filled: true,
          fillColor: Colors.black.withOpacity(0.22),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primaryCyan),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }

  Widget _scanPanel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: GlassCard(
        borderRadius: 8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: _selectedXFile == null
                  ? const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white24,
                      size: 72,
                    )
                  : Image.network(_selectedXFile!.path, fit: BoxFit.contain),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    text: 'GALLERY',
                    onPressed: _isProcessing
                        ? null
                        : () => _captureAndScanImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    text: 'CAMERA',
                    color: AppTheme.mintGreen,
                    onPressed: _isProcessing
                        ? null
                        : () => _captureAndScanImage(ImageSource.camera),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: GlassCard(
          borderRadius: 8,
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryCyan),
              const SizedBox(height: 18),
              const Text(
                'ANALYZING FOOT SCAN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Saving intake with AI pipeline',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _label(String key) {
    final spaced = key
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .replaceAll('H O', 'H/O')
        .replaceAll('ID', 'I+D')
        .replaceAll('Rt', 'RT')
        .replaceAll('Lt', 'LT')
        .trim();
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
