import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_widgets.dart';
import '../../core/theme.dart';
import '../../core/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../util/performance.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isLoading && authProvider.user == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).pushReplacementNamed('/login'),
      );
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryCyan),
        ),
      );
    }

    switch (authProvider.role) {
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.doctor:
        return const DoctorDashboard();
      case UserRole.patient:
        return const PatientDashboard();
      case UserRole.unknown:
      default:
        return const PatientDashboard();
    }
  }
}

// -------------------------------------------------------------
// PATIENT DASHBOARD
// -------------------------------------------------------------
class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  // Simple state for checklist
  @override
void initState() {
  super.initState();
  final _perf = PerformanceWrapper('PatientDashboard load');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _perf.stop();
  });
}
final Map<String, bool> _checklistState = {
    'Wash and thoroughly dry feet': true,
    'Inspect for cuts or blisters': false,
    'Apply prescribed moisturizer': false,
  };

  void _toggleChecklist(String task) {
    setState(() {
      _checklistState[task] = !(_checklistState[task] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          CustomScrollView(
            slivers: [
              _buildHeader(context, 'Patient Portal', 'Welcome Back'),
              _buildCameraQuickAccess(context),
              _buildSliverPadding(_buildRiskMeter()),
              _buildSliverPadding(_buildChecklist()),
              _buildSliverPadding(_buildAppointments()),
              _buildRecentScansStream(context, title: 'Your History', isDoctor: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskMeter() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT DFU RISK LEVEL',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'LOW RISK',
                style: TextStyle(
                  color: AppTheme.mintGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.check_circle,
                color: AppTheme.mintGreen.withOpacity(0.8),
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 0.2, // 20% risk
              backgroundColor: Colors.white10,
              minHeight: 8,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.mintGreen),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Keep up the great work! Your last scan indicated healthy tissue.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY CARE CHECKLIST',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          ..._checklistState.keys.map(
            (task) => _buildChecklistItem(task, _checklistState[task] ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isChecked) {
    return GestureDetector(
      onTap: () => _toggleChecklist(title),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked ? AppTheme.primaryCyan : Colors.transparent,
                border: Border.all(
                  color: isChecked ? AppTheme.primaryCyan : Colors.white24,
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isChecked ? Colors.white54 : Colors.white,
                  decoration: isChecked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointments() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Column(
              children: [
                Text(
                  'NOV',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '14',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dr. Henderson',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Podiatry Review',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '10:00 AM - Telehealth',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.video_call, color: AppTheme.primaryCyan),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// DOCTOR DASHBOARD
// -------------------------------------------------------------
class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final _perf = PerformanceWrapper('DoctorDashboard load');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _perf.stop();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          CustomScrollView(
            slivers: [
              _buildHeader(context, 'Dr. Henderson', 'Clinical Oversight'),
              _buildSliverPadding(_buildSearchBar()),
              _buildStatsGrid(context, isAdmin: false),
              _buildCameraQuickAccess(context),
              _buildSliverPadding(_buildActionButtons()),
              _buildSliverPadding(_buildCriticalQueueStream()),
              _buildRecentScansStream(context, title: 'Recent Scans Queue', isDoctor: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: (val) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search Patient ID or Name...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryCyan),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionBtn(
            Icons.person_add,
            'Add Patient',
            AppTheme.primaryCyan,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildActionBtn(
            Icons.assignment,
            'Generate Report',
            Colors.purpleAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalQueueStream() {
    return StreamBuilder<List<DFUReport>>(
      stream: FirestoreService().getAllReportsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final criticalReports = snapshot.data!.where((r) => r.stage >= 2).toList();
        
        if (criticalReports.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CRITICAL ATTENTION REQUIRED',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...criticalReports.take(3).map((report) {
              return _buildScanItem(
                report.userName.isEmpty ? 'Unknown Patient' : report.userName,
                'Stage ${report.stage} Detection',
                _formatTimeAgo(report.timestamp),
                Colors.red,
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

// -------------------------------------------------------------
// ADMIN DASHBOARD
// -------------------------------------------------------------
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          CustomScrollView(
            slivers: [
              _buildHeader(context, 'System Admin', 'Infrastructure Control'),
              _buildStatsGrid(context, isAdmin: true),
              _buildSliverPadding(_buildServerStatus()),
              _buildCameraQuickAccess(context),
              _buildSliverPadding(_buildUserDemographics()),
              _buildSliverPadding(_buildSystemLogs()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServerStatus() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INFRASTRUCTURE STATUS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildServerRow('FastAPI Neural Engine', '127.0.0.1:8000', true),
          const SizedBox(height: 10),
          _buildServerRow('Groq API Connection', 'groq.com/api', true),
          const SizedBox(height: 10),
          _buildServerRow('Firebase Firestore', 'Cloud', true),
        ],
      ),
    );
  }

  Widget _buildServerRow(String name, String ip, bool isUp) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isUp ? AppTheme.mintGreen : Colors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          ip,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildUserDemographics() {
    return Row(
      children: [
        Expanded(
          child: _buildDemographicCard(
            'Total Doctors',
            '42',
            Icons.medical_services,
            AppTheme.primaryCyan,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildDemographicCard(
            'Total Patients',
            '1,048',
            Icons.people,
            Colors.purpleAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildDemographicCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 15),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LATEST SYSTEM LOGS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogEntry('[200] POST /predict - Processed in 412ms'),
              _buildLogEntry('[200] GET /health - OK'),
              _buildLogEntry('[INFO] New user registered (UID: 9x8f...)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogEntry(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '> $text',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// SHARED WIDGETS & UTILS
// -------------------------------------------------------------

Widget _buildSliverPadding(Widget child) {
  return SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    sliver: SliverToBoxAdapter(child: child),
  );
}

Widget _buildBackground() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F172A), Color(0xFF0B0E14)],
      ),
    ),
  );
}

Widget _buildHeader(BuildContext context, String name, String subtitle) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              authProvider.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCameraQuickAccess(BuildContext context) {
  return _buildSliverPadding(
    GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.document_scanner,
              color: AppTheme.primaryCyan,
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI Foot Screen",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "Launch predictive model engine",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () => Navigator.pushNamed(context, '/scan'),
          ),
        ],
      ),
    ),
  );
}

Widget _buildStatsGrid(BuildContext context, {required bool isAdmin}) {
  return SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      delegate: SliverChildListDelegate([
        _buildStatCard(
          isAdmin ? 'Active Users' : 'Your Patients',
          isAdmin ? '1,090' : '241',
          Icons.people_outline,
          AppTheme.primaryCyan,
        ),
        _buildStatCard(
          'Critical',
          '12',
          Icons.warning_amber_rounded,
          Colors.redAccent,
        ),
      ]),
    ),
  );
}

Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  return GlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: color, size: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildRecentScansStream(BuildContext context, {required String title, required bool isDoctor}) {
  final stream = isDoctor
        ? FirestoreService().getAllReportsStream()
        : FirestoreService().getRecentScans(limit: 10);

  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(color: AppTheme.primaryCyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<DFUReport>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                 // Shimmer placeholder while loading
                 return Shimmer.fromColors(
                   baseColor: Colors.grey[800]!,
                   highlightColor: Colors.grey[700]!,
                   child: Column(
                     children: List.generate(3, (_) => Container(
                       margin: const EdgeInsets.symmetric(vertical: 8),
                       height: 80,
                       color: Colors.white,
                     )),
                   ),
                 );
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }
              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No recent scans found.', style: TextStyle(color: Colors.white54)),
                );
              }

              return Column(
                children: reports.map((report) {
                  Color color;
                  if (report.stage == 0) {
                    color = AppTheme.mintGreen;
                  } else if (report.stage == 1) {
                    color = Colors.yellow;
                  } else if (report.stage == 2) {
                    color = Colors.orange;
                  } else {
                    color = Colors.red;
                  }

                  String name = isDoctor ? report.userName : 'Scan ID #${report.id.length > 5 ? report.id.substring(0, 5) : report.id}';
                  if (name.isEmpty) name = 'Unknown Patient';

                  return _buildScanItem(
                    name,
                    'Stage ${report.stage} - ${report.condition}',
                    _formatTimeAgo(report.timestamp),
                    color,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
  );
}

String _formatTimeAgo(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inDays > 0) return '${difference.inDays} days ago';
  if (difference.inHours > 0) return '${difference.inHours} hours ago';
  if (difference.inMinutes > 0) return '${difference.inMinutes} mins ago';
  return 'Just now';
}

Widget _buildScanItem(String name, String status, String time, Color color) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: GlassCard(
      padding: const EdgeInsets.all(12),
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

// _buildBottomNav removed as it handled by main_wrapper.dart now.
