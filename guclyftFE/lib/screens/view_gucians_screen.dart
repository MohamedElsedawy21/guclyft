import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/admin_service.dart';

class ViewGuciansScreen extends StatefulWidget {
  const ViewGuciansScreen({super.key});

  @override
  State<ViewGuciansScreen> createState() => _ViewGuciansScreenState();
}

class _ViewGuciansScreenState extends State<ViewGuciansScreen> {
  List<GucianAdminView> _gucians = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gucians = await AdminService.getAllGucians();
      setState(() => _gucians = gucians);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registered Gucians")),
      body: _buildBody(),
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
    if (_gucians.isEmpty) {
      return const Center(child: Text("No registered gucians yet."));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _gucians.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final g = _gucians[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.navy,
                  child: Text(g.firstname[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${g.firstname} ${g.lastname}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                      Text(g.email, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      Text("${g.id} · ${g.faculty ?? 'N/A'}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                if (g.isinjured)
                  const Icon(Icons.accessible_rounded, color: AppColors.blue),
              ],
            ),
          );
        },
      ),
    );
  }
}