import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/glass_widgets.dart';
import '../../core/theme.dart';
import 'pdf_export_service.dart';

class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({super.key});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Patient Information
  DateTime? _selectedDate;
  final _fileNoCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _sex = 'Male';
  final _addressCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _refDoctorCtrl = TextEditingController();

  // 2. Medical History
  final _diabDurCtrl = TextEditingController();
  final _htnDurCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String _bmi = '';
  bool _dyslipidemia = false;
  bool _smoker = false;
  bool _cvd = false;
  bool _ckd = false;
  final _bloodSugarCtrl = TextEditingController();
  final _hba1cCtrl = TextEditingController();

  // 3. Diabetic Foot History (RT, LT)
  final _ulcerDurRtCtrl = TextEditingController();
  final _ulcerDurLtCtrl = TextEditingController();
  bool _pastUlcerRt = false, _pastUlcerLt = false;
  bool _amputationRt = false, _amputationLt = false;
  bool _jointPainRt = false, _jointPainLt = false;
  bool _stiffnessRt = false, _stiffnessLt = false;
  bool _drySkinRt = false, _drySkinLt = false;
  bool _numbnessRt = false, _numbnessLt = false;
  bool _tinglingRt = false, _tinglingLt = false;
  bool _paresthesiaRt = false, _paresthesiaLt = false;
  bool _claudicationRt = false, _claudicationLt = false;
  bool _crampingRt = false, _crampingLt = false;
  bool _oedemaRt = false, _oedemaLt = false;

  // 4. Foot Inspection (Yes/No radio/switches)
  bool _inspDrySkin = false;
  bool _inspFissure = false;
  bool _inspDeformity = false;
  bool _inspCallus = false;
  bool _inspAbnormalShape = false;
  bool _inspNailLesion = false;
  bool _inspLossOfHair = false;

  // 5. Palpation
  String _palpRt = 'Normal';
  String _palpLt = 'Normal';

  // 6. Foot Pulses
  bool _dpPulseRt = true, _dpPulseLt = true;
  bool _ptPulseRt = true, _ptPulseLt = true;

  // 7. Assessment of Neuropathy
  final _monoRtCtrl = TextEditingController();
  final _monoLtCtrl = TextEditingController();
  final _vptRtCtrl = TextEditingController();
  final _vptLtCtrl = TextEditingController();
  final _hcpRtCtrl = TextEditingController();
  final _hcpLtCtrl = TextEditingController();

  // 8. Vascular Assessment
  final _vascDpRtCtrl = TextEditingController();
  final _vascDpLtCtrl = TextEditingController();
  final _vascPtRtCtrl = TextEditingController();
  final _vascPtLtCtrl = TextEditingController();
  final _vascBrachialRtCtrl = TextEditingController();
  final _vascBrachialLtCtrl = TextEditingController();
  final _abiRtCtrl = TextEditingController();
  final _abiLtCtrl = TextEditingController();

  // 9. Radiological Investigation
  final _xrayRtCtrl = TextEditingController();
  final _xrayLtCtrl = TextEditingController();

  // 10. Ulcer Description
  final _ulcerLocCtrl = TextEditingController();
  final _ulcerSizeCtrl = TextEditingController();
  final _ulcerBaseCtrl = TextEditingController();
  final _ulcerMarginsCtrl = TextEditingController();
  final _ulcerDepthCtrl = TextEditingController();

  // 11. Clinical Diagnosis
  bool _diagNeuropathy = false;
  bool _diagCharcot = false;
  bool _diagPVD = false;
  bool _diagInfected = false;
  bool _diagOthers = false;
  final _diagOthersCtrl = TextEditingController();

  // 12. Wagner Classification
  String _wagnerClass = 'Grade 0';
  final List<String> _wagnerOptions = [
    'Grade 0',
    'Grade 1 – Superficial Ulcer',
    'Grade 2 – Deep Ulcer',
    'Grade 3 – Osteomyelitis',
    'Grade 4 – Localized Gangrene',
    'Grade 5 – Extensive Gangrene',
  ];

  // 13. Treatment Performed
  bool _txCallus = false;
  bool _txNail = false;
  bool _txID = false;
  bool _txPus = false;
  bool _txProbing = false;
  bool _txDebridement = false;
  bool _txSurgRef = false;
  bool _txOthers = false;
  final _txOthersCtrl = TextEditingController();

  // 14. Offloading Technique
  bool _offSK = false;
  bool _offShoe = false;
  bool _offTCC = false;
  bool _offInstantTCC = false;
  bool _offCustom = false;
  bool _offOthers = false;

  // 15. Follow-Up
  DateTime? _followUpDate;
  final _remarksCtrl = TextEditingController();
  final _nextVisitCtrl = TextEditingController();

  void _calculateBMI() {
    final hStr = _heightCtrl.text;
    final wStr = _weightCtrl.text;
    if (hStr.isNotEmpty && wStr.isNotEmpty) {
      try {
        final h = double.parse(hStr) / 100; // cm to m
        final w = double.parse(wStr);
        if (h > 0) {
          final bmi = w / (h * h);
          setState(() {
            _bmi = bmi.toStringAsFixed(1);
          });
        }
      } catch (_) {}
    }
  }

  @override
  void initState() {
    super.initState();
    _heightCtrl.addListener(_calculateBMI);
    _weightCtrl.addListener(_calculateBMI);
  }

  @override
  void dispose() {
    _heightCtrl.removeListener(_calculateBMI);
    _weightCtrl.removeListener(_calculateBMI);
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // BUILD HELPERS
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primaryCyan,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: lines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryCyan)),
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, ValueChanged<DateTime> onSelect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );
          if (date != null) onSelect(date);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
          ),
          child: Text(
            selectedDate == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(selectedDate),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryCyan,
        ),
      ],
    );
  }

  Widget _buildSideBySideToggles(
    String label,
    bool valRt, ValueChanged<bool> onChangeRt,
    bool valLt, ValueChanged<bool> onChangeLt
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.white70))),
          Expanded(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('RT', style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: valRt,
              onChanged: onChangeRt,
              activeColor: AppTheme.primaryCyan,
            ),
          ),
          Expanded(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('LT', style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: valLt,
              onChanged: onChangeLt,
              activeColor: AppTheme.primaryCyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: value,
        items: options.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
        onChanged: onChanged,
        dropdownColor: const Color(0xFF1E293B),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildSegmentedPalpation(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(label, style: const TextStyle(color: Colors.white70))),
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Hot', label: Text('Hot')),
                ButtonSegment(value: 'Normal', label: Text('Normal')),
                ButtonSegment(value: 'Cold', label: Text('Cold')),
              ],
              selected: {value},
              onSelectionChanged: (set) => onChanged(set.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return AppTheme.primaryCyan.withOpacity(0.3);
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _gatherFormData() {
    return {
      // Patient Information
      'date': _selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : '',
      'fileNo': _fileNoCtrl.text,
      'name': _nameCtrl.text,
      'age': _ageCtrl.text,
      'sex': _sex,
      'address': _addressCtrl.text,
      'mobile': _mobileCtrl.text,
      'refDoctor': _refDoctorCtrl.text,

      // Medical History
      'diabDur': _diabDurCtrl.text,
      'htnDur': _htnDurCtrl.text,
      'height': _heightCtrl.text,
      'weight': _weightCtrl.text,
      'bmi': _bmi,
      'dyslipidemia': _dyslipidemia,
      'smoker': _smoker,
      'cvd': _cvd,
      'ckd': _ckd,
      'bloodSugar': _bloodSugarCtrl.text,
      'hba1c': _hba1cCtrl.text,

      // Diabetic Foot History (Right/Left)
      'ulcerDurRt': _ulcerDurRtCtrl.text,
      'ulcerDurLt': _ulcerDurLtCtrl.text,
      'pastUlcerRt': _pastUlcerRt,
      'pastUlcerLt': _pastUlcerLt,
      'amputationRt': _amputationRt,
      'amputationLt': _amputationLt,
      'jointPainRt': _jointPainRt,
      'jointPainLt': _jointPainLt,
      'stiffnessRt': _stiffnessRt,
      'stiffnessLt': _stiffnessLt,
      'drySkinRt': _drySkinRt,
      'drySkinLt': _drySkinLt,
      'numbnessRt': _numbnessRt,
      'numbnessLt': _numbnessLt,
      'tinglingRt': _tinglingRt,
      'tinglingLt': _tinglingLt,
      'paresthesiaRt': _paresthesiaRt,
      'paresthesiaLt': _paresthesiaLt,
      'claudicationRt': _claudicationRt,
      'claudicationLt': _claudicationLt,
      'crampingRt': _crampingRt,
      'crampingLt': _crampingLt,
      'oedemaRt': _oedemaRt,
      'oedemaLt': _oedemaLt,

      // Foot Inspection
      'inspDrySkin': _inspDrySkin,
      'inspFissure': _inspFissure,
      'inspDeformity': _inspDeformity,
      'inspCallus': _inspCallus,
      'inspAbnormalShape': _inspAbnormalShape,
      'inspNailLesion': _inspNailLesion,
      'inspLossOfHair': _inspLossOfHair,

      // Palpation
      'palpRt': _palpRt,
      'palpLt': _palpLt,

      // Foot Pulses
      'dpPulseRt': _dpPulseRt,
      'dpPulseLt': _dpPulseLt,
      'ptPulseRt': _ptPulseRt,
      'ptPulseLt': _ptPulseLt,

      // Assessment of Neuropathy
      'monoRt': _monoRtCtrl.text,
      'monoLt': _monoLtCtrl.text,
      'vptRt': _vptRtCtrl.text,
      'vptLt': _vptLtCtrl.text,
      'hcpRt': _hcpRtCtrl.text,
      'hcpLt': _hcpLtCtrl.text,

      // Vascular Assessment
      'vascDpRt': _vascDpRtCtrl.text,
      'vascDpLt': _vascDpLtCtrl.text,
      'vascPtRt': _vascPtRtCtrl.text,
      'vascPtLt': _vascPtLtCtrl.text,
      'vascBrachialRt': _vascBrachialRtCtrl.text,
      'vascBrachialLt': _vascBrachialLtCtrl.text,
      'abiRt': _abiRtCtrl.text,
      'abiLt': _abiLtCtrl.text,

      // Radiological Investigation
      'xrayRt': _xrayRtCtrl.text,
      'xrayLt': _xrayLtCtrl.text,

      // Ulcer Description
      'ulcerLoc': _ulcerLocCtrl.text,
      'ulcerSize': _ulcerSizeCtrl.text,
      'ulcerBase': _ulcerBaseCtrl.text,
      'ulcerMargins': _ulcerMarginsCtrl.text,
      'ulcerDepth': _ulcerDepthCtrl.text,

      // Clinical Diagnosis
      'diagNeuropathy': _diagNeuropathy,
      'diagCharcot': _diagCharcot,
      'diagPVD': _diagPVD,
      'diagInfected': _diagInfected,
      'diagOthers': _diagOthers,
      'diagOthersText': _diagOthersCtrl.text,

      // Wagner Classification
      'wagnerClass': _wagnerClass,

      // Treatment Performed
      'txCallus': _txCallus,
      'txNail': _txNail,
      'txID': _txID,
      'txPus': _txPus,
      'txProbing': _txProbing,
      'txDebridement': _txDebridement,
      'txSurgRef': _txSurgRef,
      'txOthers': _txOthers,
      'txOthersText': _txOthersCtrl.text,

      // Offloading Technique
      'offSK': _offSK,
      'offShoe': _offShoe,
      'offTCC': _offTCC,
      'offInstantTCC': _offInstantTCC,
      'offCustom': _offCustom,
      'offOthers': _offOthers,

      // Follow-Up
      'followDate': _followUpDate != null ? DateFormat('dd/MM/yyyy').format(_followUpDate!) : '',
      'followRemarks': _remarksCtrl.text,
      'followNext': _nextVisitCtrl.text,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diabetic Foot Assessment', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0B0E14),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryCyan),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final data = _gatherFormData();
                await PdfExportService.generateAndDownloadAssessmentPdf(data, context);
              }
            },
          )
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildSection1(),
              const SizedBox(height: 16),
              _buildSection2(),
              const SizedBox(height: 16),
              _buildSection3(),
              const SizedBox(height: 16),
              _buildSection4_5_6(),
              const SizedBox(height: 16),
              _buildSection7_8_9(),
              const SizedBox(height: 16),
              _buildSection10_to_15(),
              const SizedBox(height: 40),
              GlassButton(
                text: 'Export as PDF',
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final data = _gatherFormData();
                    await PdfExportService.generateAndDownloadAssessmentPdf(data, context);
                  }
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection1() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('1. Patient Information'),
          _buildDatePicker('Date', _selectedDate, (val) => setState(() => _selectedDate = val)),
          _buildTextField('File Number', _fileNoCtrl),
          _buildTextField('Patient Name', _nameCtrl),
          Row(
            children: [
              Expanded(child: _buildTextField('Age', _ageCtrl, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown('Sex', _sex, ['Male', 'Female', 'Other'], (v) => setState(() => _sex = v!)),
              ),
            ],
          ),
          _buildTextField('Address', _addressCtrl, lines: 2),
          _buildTextField('Mobile Number', _mobileCtrl, isNumber: true),
          _buildTextField('Referring Doctor', _refDoctorCtrl),
        ],
      ),
    );
  }

  Widget _buildSection2() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('2. Medical History'),
          Row(
            children: [
              Expanded(child: _buildTextField('Diabetes Dur (yrs)', _diabDurCtrl, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('HTN Dur (yrs)', _htnDurCtrl, isNumber: true)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildTextField('Height (cm)', _heightCtrl, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Weight (kg)', _weightCtrl, isNumber: true)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text('Calculated BMI: ${_bmi.isEmpty ? "--" : _bmi}', style: const TextStyle(color: AppTheme.mintGreen, fontWeight: FontWeight.bold)),
          ),
          _buildToggle('Dyslipidemia', _dyslipidemia, (v) => setState(() => _dyslipidemia = v)),
          _buildToggle('Smoker', _smoker, (v) => setState(() => _smoker = v)),
          _buildToggle('Cardiovascular Disease (CVD)', _cvd, (v) => setState(() => _cvd = v)),
          _buildToggle('Chronic Kidney Disease (CKD)', _ckd, (v) => setState(() => _ckd = v)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('Blood Sugar', _bloodSugarCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('HbA1C', _hba1cCtrl)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection3() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('3. Diabetic Foot History'),
          Row(
            children: [
              Expanded(child: _buildTextField('Ulcer Dur (RT)', _ulcerDurRtCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Ulcer Dur (LT)', _ulcerDurLtCtrl)),
            ],
          ),
          _buildSideBySideToggles('Past Hx of Ulcer', _pastUlcerRt, (v) => setState(() => _pastUlcerRt = v), _pastUlcerLt, (v) => setState(() => _pastUlcerLt = v)),
          _buildSideBySideToggles('Amputation', _amputationRt, (v) => setState(() => _amputationRt = v), _amputationLt, (v) => setState(() => _amputationLt = v)),
          _buildSideBySideToggles('Joint Pain', _jointPainRt, (v) => setState(() => _jointPainRt = v), _jointPainLt, (v) => setState(() => _jointPainLt = v)),
          _buildSideBySideToggles('Stiffness', _stiffnessRt, (v) => setState(() => _stiffnessRt = v), _stiffnessLt, (v) => setState(() => _stiffnessLt = v)),
          _buildSideBySideToggles('Dry Skin', _drySkinRt, (v) => setState(() => _drySkinRt = v), _drySkinLt, (v) => setState(() => _drySkinLt = v)),
          _buildSideBySideToggles('Numbness', _numbnessRt, (v) => setState(() => _numbnessRt = v), _numbnessLt, (v) => setState(() => _numbnessLt = v)),
          _buildSideBySideToggles('Tingling/Pricking', _tinglingRt, (v) => setState(() => _tinglingRt = v), _tinglingLt, (v) => setState(() => _tinglingLt = v)),
          _buildSideBySideToggles('Paresthesia', _paresthesiaRt, (v) => setState(() => _paresthesiaRt = v), _paresthesiaLt, (v) => setState(() => _paresthesiaLt = v)),
          _buildSideBySideToggles('Claudication', _claudicationRt, (v) => setState(() => _claudicationRt = v), _claudicationLt, (v) => setState(() => _claudicationLt = v)),
          _buildSideBySideToggles('Cramping', _crampingRt, (v) => setState(() => _crampingRt = v), _crampingLt, (v) => setState(() => _crampingLt = v)),
          _buildSideBySideToggles('Oedema', _oedemaRt, (v) => setState(() => _oedemaRt = v), _oedemaLt, (v) => setState(() => _oedemaLt = v)),
        ],
      ),
    );
  }

  Widget _buildSection4_5_6() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('4. Foot Inspection'),
          _buildToggle('Dry Skin', _inspDrySkin, (v) => setState(() => _inspDrySkin = v)),
          _buildToggle('Fissure', _inspFissure, (v) => setState(() => _inspFissure = v)),
          _buildToggle('Deformity', _inspDeformity, (v) => setState(() => _inspDeformity = v)),
          _buildToggle('Callus', _inspCallus, (v) => setState(() => _inspCallus = v)),
          _buildToggle('Abnormal Shape', _inspAbnormalShape, (v) => setState(() => _inspAbnormalShape = v)),
          _buildToggle('Nail Lesion', _inspNailLesion, (v) => setState(() => _inspNailLesion = v)),
          _buildToggle('Loss of Hair', _inspLossOfHair, (v) => setState(() => _inspLossOfHair = v)),
          const SizedBox(height: 16),
          
          _buildSectionHeader('5. Palpation'),
          _buildSegmentedPalpation('RT', _palpRt, (v) => setState(() => _palpRt = v)),
          _buildSegmentedPalpation('LT', _palpLt, (v) => setState(() => _palpLt = v)),
          const SizedBox(height: 16),
          
          _buildSectionHeader('6. Foot Pulses (Present/Absent)'),
          _buildSideBySideToggles('Dorsalis Pedis', _dpPulseRt, (v) => setState(() => _dpPulseRt = v), _dpPulseLt, (v) => setState(() => _dpPulseLt = v)),
          _buildSideBySideToggles('Posterior Tibialis', _ptPulseRt, (v) => setState(() => _ptPulseRt = v), _ptPulseLt, (v) => setState(() => _ptPulseLt = v)),
        ],
      ),
    );
  }

  Widget _buildSection7_8_9() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('7. Assessment of Neuropathy'),
          Row(
            children: [
              Expanded(child: _buildTextField('Monofilament (RT)', _monoRtCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Monofilament (LT)', _monoLtCtrl)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildTextField('VPT (RT)', _vptRtCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('VPT (LT)', _vptLtCtrl)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildTextField('HCP (RT)', _hcpRtCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('HCP (LT)', _hcpLtCtrl)),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('8. Vascular Assessment'),
          Row(
            children: [
              Expanded(child: _buildTextField('ABI (RT)', _abiRtCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('ABI (LT)', _abiLtCtrl)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildTextField('Brachial Pulse (RT)', _vascBrachialRtCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Brachial Pulse (LT)', _vascBrachialLtCtrl)),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('9. Radiological Inv. (X-Ray)'),
          _buildTextField('Right Foot Findings', _xrayRtCtrl, lines: 3),
          _buildTextField('Left Foot Findings', _xrayLtCtrl, lines: 3),
        ],
      ),
    );
  }

  Widget _buildSection10_to_15() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('10. Ulcer Description'),
          _buildTextField('Location', _ulcerLocCtrl),
          Row(
            children: [
              Expanded(child: _buildTextField('Size', _ulcerSizeCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Depth', _ulcerDepthCtrl)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildTextField('Base', _ulcerBaseCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Margins', _ulcerMarginsCtrl)),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('11. Clinical Diagnosis'),
          _buildToggle('Neuropathy', _diagNeuropathy, (v) => setState(() => _diagNeuropathy = v)),
          _buildToggle('Charcot Foot', _diagCharcot, (v) => setState(() => _diagCharcot = v)),
          _buildToggle('PVD', _diagPVD, (v) => setState(() => _diagPVD = v)),
          _buildToggle('Infected', _diagInfected, (v) => setState(() => _diagInfected = v)),
          _buildToggle('Others', _diagOthers, (v) => setState(() => _diagOthers = v)),
          if (_diagOthers) _buildTextField('Others (Specify)', _diagOthersCtrl),
          const SizedBox(height: 16),

          _buildSectionHeader('12. Wagner Classification'),
          _buildDropdown('Grade', _wagnerClass, _wagnerOptions, (v) => setState(() => _wagnerClass = v!)),
          const SizedBox(height: 16),

          _buildSectionHeader('13. Treatment Performed'),
          _buildToggle('Callus and Corn Removed', _txCallus, (v) => setState(() => _txCallus = v)),
          _buildToggle('Nail Paring', _txNail, (v) => setState(() => _txNail = v)),
          _buildToggle('I + D Done', _txID, (v) => setState(() => _txID = v)),
          _buildToggle('Pus for C/S', _txPus, (v) => setState(() => _txPus = v)),
          _buildToggle('Probing', _txProbing, (v) => setState(() => _txProbing = v)),
          _buildToggle('Extensive Debridement', _txDebridement, (v) => setState(() => _txDebridement = v)),
          _buildToggle('Surgical Referral', _txSurgRef, (v) => setState(() => _txSurgRef = v)),
          _buildToggle('Others', _txOthers, (v) => setState(() => _txOthers = v)),
          if (_txOthers) _buildTextField('Others (Specify)', _txOthersCtrl),
          const SizedBox(height: 16),

          _buildSectionHeader('14. Offloading Technique'),
          _buildToggle('S.K. Offloading', _offSK, (v) => setState(() => _offSK = v)),
          _buildToggle('Offloading Shoe', _offShoe, (v) => setState(() => _offShoe = v)),
          _buildToggle('Total Contact Cast', _offTCC, (v) => setState(() => _offTCC = v)),
          _buildToggle('Instant TCC', _offInstantTCC, (v) => setState(() => _offInstantTCC = v)),
          _buildToggle('Custom Footwear', _offCustom, (v) => setState(() => _offCustom = v)),
          _buildToggle('Others', _offOthers, (v) => setState(() => _offOthers = v)),
          const SizedBox(height: 16),

          _buildSectionHeader('15. Follow-Up'),
          _buildDatePicker('Follow-up Date', _followUpDate, (v) => setState(() => _followUpDate = v)),
          _buildTextField('Doctor Remarks', _remarksCtrl, lines: 3),
          _buildTextField('Next Visit Instructions', _nextVisitCtrl, lines: 3),
        ],
      ),
    );
  }
}
