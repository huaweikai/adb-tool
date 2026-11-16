import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../i18n.dart';
import '../providers/device_provider.dart';
import '../services/api_client.dart';
import '../usecases/attach_crash_report.dart';

class IosCrashReportsScreen extends StatefulWidget {
  const IosCrashReportsScreen({super.key});

  @override
  State<IosCrashReportsScreen> createState() => _IosCrashReportsScreenState();
}

class _IosCrashReportsScreenState extends State<IosCrashReportsScreen> {
  String? _serial;
  Future<List<String>>? _reports;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final serial = context.watch<DeviceSerialScope>().serial;
    final devices = context.watch<DeviceProvider>();
    final target = devices.isDeviceConnected(serial) ? serial : null;
    if (target != _serial) {
      _serial = target;
      _reports = target == null
          ? null
          : context.read<ApiClient>().getIOSCrashReports(target);
    }
  }

  void _refresh() {
    final serial = _serial;
    if (serial == null) return;
    setState(
        () => _reports = context.read<ApiClient>().getIOSCrashReports(serial));
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${tr('iosCrashReportActionFailed')}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(String serial, String name) => _runAction(() async {
        final api = context.read<ApiClient>();
        final location = await getSaveLocation(suggestedName: name);
        if (location == null) return;
        final bytes = await api.getIOSCrashReport(serial, name);
        await File(location.path).writeAsBytes(bytes);
      });

  Future<void> _attach(String serial, String name) => _runAction(() async {
        final api = context.read<ApiClient>();
        final db = context.read<DeviceProvider>().db;
        final targets = await db.testSessionsDao.issueAttachmentTargets();
        if (!mounted) return;
        final issue = await showDialog<TestSessionIssueRow>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(tr('iosCrashReportAttach')),
            content: SizedBox(
              width: 480,
              height: targets.isEmpty ? null : 360,
              child: targets.isEmpty
                  ? Text(tr('iosCrashReportNoIssues'))
                  : ListView.builder(
                      itemCount: targets.length,
                      itemBuilder: (context, index) {
                        final target = targets[index];
                        final device = target.session.deviceModel.isEmpty
                            ? target.session.deviceSerial
                            : target.session.deviceModel;
                        return ListTile(
                          title: Text(target.issue.title),
                          subtitle: Text('${target.session.name} · $device'),
                          onTap: () =>
                              Navigator.of(dialogContext).pop(target.issue),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr('cancel')),
              ),
            ],
          ),
        );
        if (issue == null) return;
        final bytes = await api.getIOSCrashReport(serial, name);
        await attachCrashReport(db: db, issue: issue, name: name, bytes: bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('iosCrashReportAttached'))),
          );
        }
      });

  @override
  Widget build(BuildContext context) {
    final serial = _serial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(tr('iosCrashReports')),
          trailing: IconButton(
            tooltip: tr('retry'),
            onPressed: serial == null || _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: serial == null
              ? Center(child: Text(tr('iosCrashReportsOffline')))
              : FutureBuilder<List<String>>(
                  future: _reports,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                            '${tr('iosCrashReportsLoadFailed')}: ${snapshot.error}'),
                      );
                    }
                    final reports = snapshot.data ?? const [];
                    if (reports.isEmpty) {
                      return Center(child: Text(tr('iosCrashReportsEmpty')));
                    }
                    return ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final name = reports[index];
                        return ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: tr('iosCrashReportSave'),
                                onPressed:
                                    _busy ? null : () => _save(serial, name),
                                icon: const Icon(Icons.download_outlined),
                              ),
                              IconButton(
                                tooltip: tr('iosCrashReportAttach'),
                                onPressed:
                                    _busy ? null : () => _attach(serial, name),
                                icon: const Icon(Icons.attach_file),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
