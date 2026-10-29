import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/medical_service.dart';


class AccountScreen extends StatefulWidget {
  final String name;
  const AccountScreen({super.key, required this.name});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<MedicalRequestModel> _requests = [];
  bool _loading = true;
  String? _error;

  String _requestType = "injury";
  String? _pickedFilePath;
  String? _pickedFileName;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await MedicalService.getMyRequests();
      setState(() => _requests = requests);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
  );

  if (files.isNotEmpty) {
    final file = files.first;

    if (file.path != null) {
      setState(() {
        _pickedFilePath = file.path;
        _pickedFileName = file.name;
      });
    }
  }
}

  Future<void> _submit() async {
    if (_pickedFilePath == null) {
      setState(() => _submitError = "Please attach a document");
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await MedicalService.submitRequest(requestType: _requestType, filePath: _pickedFilePath!);
      setState(() {
        _pickedFilePath = null;
        _pickedFileName = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request submitted — pending admin review")),
      );
      _loadRequests();
    } catch (e) {
      setState(() => _submitError = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _submitting = false);
    }
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
      appBar: AppBar(title: const Text("My Account")),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.navy,
              child: Text(widget.name.isNotEmpty ? widget.name[0].toUpperCase() : "?",
                  style: const TextStyle(color: Colors.white, fontSize: 28)),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(widget.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            const SizedBox(height: 32),
            const Text("Request Priority Access",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 6),
            const Text(
              "Submit a medical document if you're injured or have a disability. Approved requests grant priority booking.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _requestType,
                    decoration: const InputDecoration(labelText: "Request Type"),
                    items: const [
                      DropdownMenuItem(value: "injury", child: Text("Injury (temporary)")),
                      DropdownMenuItem(value: "disability", child: Text("Disability (permanent)")),
                    ],
                    onChanged: (v) => setState(() => _requestType = v!),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_pickedFileName ?? "Attach Medical Document"),
                  ),
                  if (_submitError != null) ...[
                    const SizedBox(height: 8),
                    Text(_submitError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Submit Request"),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text("My Requests", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error))
            else if (_requests.isEmpty)
              const Text("No requests submitted yet.", style: TextStyle(color: Colors.grey))
            else
              ..._requests.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          r.requestType == "disability" ? Icons.accessible_rounded : Icons.healing_rounded,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.requestType[0].toUpperCase() + r.requestType.substring(1),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (r.status == "approved" && r.priorityUntil != null)
                                Text("Priority until: ${r.priorityUntil!.substring(0, 10)}",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (r.status == "approved" && r.priorityUntil == null)
                                const Text("Permanent priority", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  )),
          ],
        ),
      ),
    );
  }
}