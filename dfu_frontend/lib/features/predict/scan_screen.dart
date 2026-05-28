import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../widgets/glass_widgets.dart';
import '../../core/theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isProcessing = false;
  XFile? _selectedXFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureAndScanImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _selectedXFile = pickedFile;
        _isProcessing = true;
      });

      // 1. Create Multipart Request
      // Using Vercel production backend
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://dfu-app-z513.vercel.app/predict'),
      );

      // 2. Attach File
      if (kIsWeb) {
        // On web, fromPath is not supported. Use fromBytes.
        final bytes = await pickedFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: pickedFile.name,
          ),
        );
      } else {
        // On mobile, fromPath is efficient as it streams from disk
        request.files.add(
          await http.MultipartFile.fromPath('file', pickedFile.path),
        );
      }

      // 3. Send Request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (mounted) {
        setState(() => _isProcessing = false);

        // 4. Handle Response
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // data contains: {"success": true, "prediction": {...}, "clinical_report": "...", "ai_insights": "..."}
          Navigator.pushReplacementNamed(
            context,
            '/results',
            arguments: {'imagePath': pickedFile.path, 'prediction': data},
          );
        } else {
          _showError("Server Error: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError("Failed to connect to backend: $e");
      }
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
          // Camera Viewfinder (Background)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            // Show the selected image as a whole (no bounded viewfinder crop)
            child: _selectedXFile != null
                ? (kIsWeb
                      ? Image.network(
                          _selectedXFile!.path,
                          fit: BoxFit.contain,
                          opacity: const AlwaysStoppedAnimation(0.5),
                        )
                      : Image.network(
                          _selectedXFile!.path,
                          fit: BoxFit.contain,
                          opacity: const AlwaysStoppedAnimation(0.5),
                        ))
                : const Center(
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white24,
                      size: 100,
                    ),
                  ),
          ),

          // UI Elements
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildTopBar(context), _buildBottomControls()],
            ),
          ),

          // Processing Modal
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const GlassCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: 12,
            child: Text(
              'ALIGN FOOT IN FRAME',
              style: TextStyle(
                color: AppTheme.primaryCyan,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.flash_off, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinderOverlay() {
    return Center(
      child: Container(
        width: 280,
        height: 450,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.primaryCyan.withOpacity(0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // Corners
            const _ViewfinderCorner(top: 0, left: 0, rotation: 0),
            const _ViewfinderCorner(top: 0, right: 0, rotation: 1.57),
            const _ViewfinderCorner(bottom: 0, left: 0, rotation: -1.57),
            const _ViewfinderCorner(bottom: 0, right: 0, rotation: 3.14),

            // Scanning Line Animation (Placeholder)
            if (_isProcessing) _buildScanningLine(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningLine() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0, // In a real app we'd animate `top` from 0 to 450
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryCyan,
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery Picker
          GestureDetector(
            onTap: () => _captureAndScanImage(ImageSource.gallery),
            child: const _ControlCircle(icon: Icons.photo_library_outlined),
          ),

          // Camera Capture
          GestureDetector(
            onTap: () => _captureAndScanImage(ImageSource.camera),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          const _ControlCircle(icon: Icons.history),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: GlassCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryCyan),
              const SizedBox(height: 20),
              const Text(
                'AI ANALYZING MODEL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Connecting to FastAPI via Groq',
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
}

class _ViewfinderCorner extends StatelessWidget {
  final double? top, bottom, left, right, rotation;
  const _ViewfinderCorner({
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: rotation!,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.primaryCyan, width: 4),
              left: BorderSide(color: AppTheme.primaryCyan, width: 4),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlCircle extends StatelessWidget {
  final IconData icon;
  const _ControlCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}
