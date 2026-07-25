import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/glass_widgets.dart';
import '../../core/theme.dart';
import '../../services/firestore_service.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final TextEditingController _nameController = TextEditingController();
  List<DFUReport>? _results;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Enter a patient name to search records.';
        _results = null;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final reports = await FirestoreService().searchReportsByName(name);
      setState(() {
        _results = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.hospitalBackground),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Records',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Search by Patient Name',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                sliver: SliverToBoxAdapter(child: _buildSearchBar()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: _buildResultsSliver(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: TextField(
        controller: _nameController,
        style: const TextStyle(color: AppTheme.textDark),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: 'Patient name (required)...',
          hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.6)),
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryCyan),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward, color: AppTheme.primaryCyan),
            onPressed: _search,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildResultsSliver() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),
        ),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }

    if (_results == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'Enter a name above to find all records for that patient.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      );
    }

    if (_results!.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'No records found for that name.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildRecordItem(_results![index]),
        childCount: _results!.length,
      ),
    );
  }

  Widget _buildRecordItem(DFUReport report) {
    Color color;
    if (report.stage == 0) {
      color = AppTheme.mintGreen;
    } else if (report.stage == 1) {
      color = Colors.yellow.shade700;
    } else if (report.stage == 2) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    final name = report.userName.isEmpty ? 'Unknown Patient' : report.userName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.description_outlined, color: color),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stage ${report.stage} - ${report.condition}',
                    style: TextStyle(color: color.withOpacity(0.9), fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.fileNo.isEmpty ? report.id : report.fileNo,
                    style: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (report.pdfUrl.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryCyan),
                onPressed: () => launchUrl(
                  Uri.parse(report.pdfUrl),
                  mode: LaunchMode.externalApplication,
                  webOnlyWindowName: '_blank',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
