import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/admin_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicalRequestsScreen extends StatefulWidget {
  const MedicalRequestsScreen({super.key});

  @override
  State<MedicalRequestsScreen> createState() => _MedicalRequestsScreenState();
}

class _MedicalRequestsScreenState extends State<MedicalRequestsScreen> {
  List<MedicalRequestAdminModel> _requests = [];
  bool _loading = true;
  String? _error;
  String _filter = "pending";

  @override
  void initState() {
    super.initState();
    _load();
  }

    Future<void> _viewDocument(int requestId) async {
    final url = await AdminService.getDocumentUrl(requestId);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open document")),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await AdminService.getAllMedicalRequests(status: _filter == "all" ? null : _filter);
      setState(() => _requests = requests);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _review(MedicalRequestAdminModel req, String status) async {
    int? days;
    if (status == "approved" && req.requestType == "injury") {
      days = await _askPriorityDays();
      if (days == null) return; // cancelled
    }
    try {
      await AdminService.reviewMedicalRequest(requestId: req.id, status: status, priorityDays: days);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request ${status == 'approved' ? 'approved' : 'rejected'}")),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
      );
    }
  }

  Future<int?> _askPriorityDays() async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Priority Duration"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Number of days"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final days = int.tryParse(controller.text);
              if (days != null && days > 0) {
                Navigator.pop(context, days);
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green;
      case "rejected":
        return AppColors.error;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medical Verification")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: "pending", label: Text("Pending")),
                ButtonSegment(value: "approved", label: Text("Approved")),
                ButtonSegment(value: "rejected", label: Text("Rejected")),
                ButtonSegment(value: "all", label: Text("All")),
              ],
              selected: {_filter},
              onSelectionChanged: (s) {
                setState(() => _filter = s.first);
                _load();
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text("Retry")),
          ],
        ),
      );
    }
    if (_requests.isEmpty) {
      return const Center(child: Text("No requests found."));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final r = _requests[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      r.requestType == "disability" ? Icons.accessible_rounded : Icons.healing_rounded,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.gucianName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text("${r.gucianId} · ${r.requestType}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(r.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(r.status, style: TextStyle(color: _statusColor(r.status), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                                InkWell(
                  onTap: () => _viewDocument(r.id),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 16, color: AppColors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          r.documentPath.split('/').last,
                          style: const TextStyle(fontSize: 13, color: AppColors.blue, decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.open_in_new, size: 14, color: AppColors.blue),
                    ],
                  ),
                ),
                if (r.status == "approved") ...[
                  const SizedBox(height: 6),
                  Text(
                    r.priorityUntil != null
                        ? "Priority until: ${r.priorityUntil!.substring(0, 10)}"
                        : "Permanent priority",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                if (r.status == "pending") ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _review(r, "rejected"),
                          icon: const Icon(Icons.close, color: AppColors.error),
                          label: const Text("Reject", style: TextStyle(color: AppColors.error)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _review(r, "approved"),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text("Approve"),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}