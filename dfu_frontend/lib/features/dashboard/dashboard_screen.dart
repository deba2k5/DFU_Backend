import 'package:flutter/material.dart';
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
    final perf = PerformanceWrapper('PatientDashboard load');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      perf.stop();
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskMeter() {
    return StreamBuilder<List<DFUReport>>(
      stream: FirestoreService().getRecentScans(limit: 1),
      builder: (context, snapshot) {
        final latest = (snapshot.data ?? []).isEmpty
            ? null
            : snapshot.data!.first;
        final stage = latest?.stage ?? 0;
        final color = stage <= 0
            ? AppTheme.mintGreen
            : stage == 1
            ? Colors.orangeAccent
            : Colors.redAccent;
        final label = latest == null
            ? 'NO SCAN YET'
            : stage <= 0
            ? 'LOW RISK'
            : stage == 1
            ? 'WATCH'
            : 'CLINICAL REVIEW';
        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CURRENT DFU RISK LEVEL',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    stage >= 2
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle,
                    color: color.withOpacity(0.8),
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: latest == null ? 0 : (stage + 1) / 6,
                  backgroundColor: AppTheme.cardBorder,
                  minHeight: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                latest == null
                    ? 'Start a foot scan to create your first clinical report.'
                    : 'Latest report: Stage ${latest.stage} - ${latest.condition}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        );
      },
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
              color: AppTheme.textMuted,
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
                  color: isChecked ? AppTheme.primaryCyan : AppTheme.cardBorder,
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
                  color: isChecked ? AppTheme.textMuted : AppTheme.textDark,
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
  @override
  void initState() {
    super.initState();
    final perf = PerformanceWrapper('DoctorDashboard load');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      perf.stop();
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
              _buildHeader(context, 'Doctor Portal', 'Clinical Oversight'),
              _buildStatsGrid(context, isAdmin: false),
              _buildCameraQuickAccess(context),
              _buildSliverPadding(_buildActionButtons()),
            ],
          ),
        ],
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
            () {
              // Add patient logic
            },
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildActionBtn(
            Icons.assignment,
            'Generate Report',
            Colors.purpleAccent,
            () {
              Navigator.pushNamed(context, '/assessment');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildServerRow('FastAPI Neural Engine', BackendConfig.baseUrl, true),
          const SizedBox(height: 10),
          _buildServerRow('Groq API Connection', 'groq.com/api', true),
          const SizedBox(height: 10),
          _buildServerRow('MongoDB + ChromaDB Reports', 'Cloud', true),
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
              color: AppTheme.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          ip,
          style: TextStyle(color: AppTheme.textMuted.withOpacity(0.4), fontSize: 12),
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
              color: AppTheme.textDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textMuted.withOpacity(0.5),
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
            color: AppTheme.textDark,
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
      gradient: AppTheme.hospitalBackground,
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
                    color: AppTheme.textMuted.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textDark,
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
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "Launch predictive model engine",
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textDark,
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
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: StreamBuilder<List<DFUReport>>(
        stream: FirestoreService().getAllReportsStream(),
        builder: (context, snapshot) {
          final reports = snapshot.data ?? [];
          final patientIds = reports
              .map(
                (report) =>
                    report.patient['mobile']?.toString() ?? report.userName,
              )
              .where((value) => value.isNotEmpty)
              .toSet();
          final critical = reports.where((report) => report.stage >= 2).length;
          return GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                isAdmin ? 'Stored Patients' : 'Patient Records',
                patientIds.length.toString(),
                Icons.people_outline,
                AppTheme.primaryCyan,
              ),
              _buildStatCard(
                'Critical',
                critical.toString(),
                Icons.warning_amber_rounded,
                Colors.redAccent,
              ),
            ],
          );
        },
      ),
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
                color: AppTheme.textDark,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textMuted.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// _buildBottomNav removed as it handled by main_wrapper.dart now.
