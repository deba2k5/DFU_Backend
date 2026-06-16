import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  static Future<void> generateAndDownloadAssessmentPdf(
      Map<String, dynamic> data, BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          List<pw.Widget> widgets = [
            _buildHeader(),
            pw.SizedBox(height: 20),
            _buildSectionTitle('1. Patient Information'),
            _buildRow('Date', data['date'], 'File Number', data['fileNo']),
            _buildRow('Patient Name', data['name'], 'Age', data['age']),
            _buildRow('Sex', data['sex'], 'Mobile', data['mobile']),
            _buildSingleRow('Address', data['address']),
            _buildSingleRow('Referring Doctor', data['refDoctor']),
            pw.SizedBox(height: 10),
            _buildSectionTitle('2. Medical History'),
            _buildRow('Diabetes Duration', data['diabDur'], 'HTN Duration', data['htnDur']),
            _buildRow('Height (cm)', data['height'], 'Weight (kg)', data['weight']),
            _buildRow('BMI', data['bmi'], 'Blood Sugar', data['bloodSugar']),
            _buildRow('HbA1C', data['hba1c'], 'Smoker', data['smoker'] ? 'Yes' : 'No'),
            _buildRow('Dyslipidemia', data['dyslipidemia'] ? 'Yes' : 'No', 'CVD', data['cvd'] ? 'Yes' : 'No'),
            _buildSingleRow('CKD', data['ckd'] ? 'Yes' : 'No'),
            pw.SizedBox(height: 10),
            _buildSectionTitle('3. Diabetic Foot History'),
            _buildRow('Ulcer Duration (Right)', data['ulcerDurRt'], 'Ulcer Duration (Left)', data['ulcerDurLt']),
            _buildRow('Past Ulcer (Right)', data['pastUlcerRt'] ? 'Yes' : 'No', 'Past Ulcer (Left)', data['pastUlcerLt'] ? 'Yes' : 'No'),
            _buildRow('Amputation (Right)', data['amputationRt'] ? 'Yes' : 'No', 'Amputation (Left)', data['amputationLt'] ? 'Yes' : 'No'),
            _buildRow('Joint Pain (Right)', data['jointPainRt'] ? 'Yes' : 'No', 'Joint Pain (Left)', data['jointPainLt'] ? 'Yes' : 'No'),
            _buildRow('Stiffness (Right)', data['stiffnessRt'] ? 'Yes' : 'No', 'Stiffness (Left)', data['stiffnessLt'] ? 'Yes' : 'No'),
            _buildRow('Dry Skin (Right)', data['drySkinRt'] ? 'Yes' : 'No', 'Dry Skin (Left)', data['drySkinLt'] ? 'Yes' : 'No'),
            _buildRow('Numbness (Right)', data['numbnessRt'] ? 'Yes' : 'No', 'Numbness (Left)', data['numbnessLt'] ? 'Yes' : 'No'),
            _buildRow('Tingling (Right)', data['tinglingRt'] ? 'Yes' : 'No', 'Tingling (Left)', data['tinglingLt'] ? 'Yes' : 'No'),
            _buildRow('Paresthesia (Right)', data['paresthesiaRt'] ? 'Yes' : 'No', 'Paresthesia (Left)', data['paresthesiaLt'] ? 'Yes' : 'No'),
            _buildRow('Claudication (Right)', data['claudicationRt'] ? 'Yes' : 'No', 'Claudication (Left)', data['claudicationLt'] ? 'Yes' : 'No'),
            _buildRow('Cramping (Right)', data['crampingRt'] ? 'Yes' : 'No', 'Cramping (Left)', data['crampingLt'] ? 'Yes' : 'No'),
            _buildRow('Oedema (Right)', data['oedemaRt'] ? 'Yes' : 'No', 'Oedema (Left)', data['oedemaLt'] ? 'Yes' : 'No'),
            pw.SizedBox(height: 10),
            _buildSectionTitle('4. Foot Inspection'),
            _buildRow('Dry Skin', data['inspDrySkin'] ? 'Yes' : 'No', 'Fissure', data['inspFissure'] ? 'Yes' : 'No'),
            _buildRow('Deformity', data['inspDeformity'] ? 'Yes' : 'No', 'Callus', data['inspCallus'] ? 'Yes' : 'No'),
            _buildRow('Abnormal Shape', data['inspAbnormalShape'] ? 'Yes' : 'No', 'Nail Lesion', data['inspNailLesion'] ? 'Yes' : 'No'),
            _buildSingleRow('Loss of Hair', data['inspLossOfHair'] ? 'Yes' : 'No'),
            pw.SizedBox(height: 10),
            _buildSectionTitle('5. Palpation'),
            _buildRow('Right', data['palpRt'], 'Left', data['palpLt']),
            pw.SizedBox(height: 10),
            _buildSectionTitle('6. Foot Pulses'),
            _buildRow('Dorsalis Pedis (Right)', data['dpPulseRt'] ? 'Present' : 'Absent', 'Dorsalis Pedis (Left)', data['dpPulseLt'] ? 'Present' : 'Absent'),
            _buildRow('Posterior Tibialis (Right)', data['ptPulseRt'] ? 'Present' : 'Absent', 'Posterior Tibialis (Left)', data['ptPulseLt'] ? 'Present' : 'Absent'),
            pw.SizedBox(height: 10),
            _buildSectionTitle('7. Assessment of Neuropathy'),
            _buildRow('Monofilament (Right)', data['monoRt'], 'Monofilament (Left)', data['monoLt']),
            _buildRow('VPT (Right)', data['vptRt'], 'VPT (Left)', data['vptLt']),
            _buildRow('HCP (Right)', data['hcpRt'], 'HCP (Left)', data['hcpLt']),
            pw.SizedBox(height: 10),
            _buildSectionTitle('8. Vascular Assessment'),
            _buildRow('Dorsalis Pedis (Right)', data['vascDpRt'], 'Dorsalis Pedis (Left)', data['vascDpLt']),
            _buildRow('Posterior Tibialis (Right)', data['vascPtRt'], 'Posterior Tibialis (Left)', data['vascPtLt']),
            _buildRow('Brachial (Right)', data['vascBrachialRt'], 'Brachial (Left)', data['vascBrachialLt']),
            _buildRow('ABI (Right)', data['abiRt'], 'ABI (Left)', data['abiLt']),
            pw.SizedBox(height: 10),
            _buildSectionTitle('9. Radiological Investigation'),
            _buildSingleRow('Right Foot X-Ray', data['xrayRt']),
            _buildSingleRow('Left Foot X-Ray', data['xrayLt']),
            pw.SizedBox(height: 10),
            _buildSectionTitle('10. Ulcer Description'),
            _buildSingleRow('Location', data['ulcerLoc']),
            _buildRow('Size', data['ulcerSize'], 'Depth', data['ulcerDepth']),
            _buildRow('Base', data['ulcerBase'], 'Margins', data['ulcerMargins']),
            pw.SizedBox(height: 10),
            _buildSectionTitle('11. Clinical Diagnosis'),
            _buildRow('Neuropathy', data['diagNeuropathy'] ? 'Yes' : 'No', 'Charcot Foot', data['diagCharcot'] ? 'Yes' : 'No'),
            _buildRow('PVD', data['diagPVD'] ? 'Yes' : 'No', 'Infected', data['diagInfected'] ? 'Yes' : 'No'),
            _buildRow('Others', data['diagOthers'] ? 'Yes' : 'No', '', ''),
          ];
          if (data['diagOthers'] == true) {
            widgets.add(_buildSingleRow('Others (Specify)', data['diagOthersText']));
          }
          widgets.addAll([
            pw.SizedBox(height: 10),
            _buildSectionTitle('12. Wagner Classification'),
            _buildSingleRow('Grade', data['wagnerClass']),
            pw.SizedBox(height: 10),
            _buildSectionTitle('13. Treatment Performed'),
            _buildRow('Callus and Corn Removed', data['txCallus'] ? 'Yes' : 'No', 'Nail Paring', data['txNail'] ? 'Yes' : 'No'),
            _buildRow('I + D Done', data['txID'] ? 'Yes' : 'No', 'Pus for C/S', data['txPus'] ? 'Yes' : 'No'),
            _buildRow('Probing', data['txProbing'] ? 'Yes' : 'No', 'Extensive Debridement', data['txDebridement'] ? 'Yes' : 'No'),
            _buildRow('Surgical Referral', data['txSurgRef'] ? 'Yes' : 'No', 'Others', data['txOthers'] ? 'Yes' : 'No'),
          ]);
          if (data['txOthers'] == true) {
            widgets.add(_buildSingleRow('Others (Specify)', data['txOthersText']));
          }
          widgets.addAll([
            pw.SizedBox(height: 10),
            _buildSectionTitle('14. Offloading Technique'),
            _buildRow('S.K. Offloading', data['offSK'] ? 'Yes' : 'No', 'Offloading Shoe', data['offShoe'] ? 'Yes' : 'No'),
            _buildRow('Total Contact Cast', data['offTCC'] ? 'Yes' : 'No', 'Instant TCC', data['offInstantTCC'] ? 'Yes' : 'No'),
            _buildRow('Custom Footwear', data['offCustom'] ? 'Yes' : 'No', 'Others', data['offOthers'] ? 'Yes' : 'No'),
            pw.SizedBox(height: 10),
            _buildSectionTitle('15. Follow-Up'),
            _buildSingleRow('Follow-Up Date', data['followDate']),
            _buildSingleRow('Doctor Remarks', data['followRemarks']),
            _buildSingleRow('Next Visit Instructions', data['followNext']),
            pw.SizedBox(height: 20),
            pw.Text('Generated by DFU Screening System', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ]);
          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Assessment_${data['name'] ?? 'Patient'}.pdf',
    );
  }

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Diabetic Foot Assessment Form',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.SizedBox(height: 4),
        pw.Text('Hospital Management System - Clinical Report',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8, top: 12),
      padding: const pw.EdgeInsets.all(4),
      color: PdfColors.grey200,
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildRow(String label1, dynamic value1, String label2, dynamic value2) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Expanded(child: _buildItem(label1, value1?.toString() ?? '')),
          pw.Expanded(child: _buildItem(label2, value2?.toString() ?? '')),
        ],
      ),
    );
  }

  static pw.Widget _buildSingleRow(String label, dynamic value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: _buildItem(label, value?.toString() ?? ''),
    );
  }

  static pw.Widget _buildItem(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Expanded(child: pw.Text(value.isEmpty ? '--' : value, style: const pw.TextStyle(fontSize: 10))),
      ],
    );
  }
}
