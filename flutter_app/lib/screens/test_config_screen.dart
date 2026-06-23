import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';
import '../models/test_config.dart';
import '../providers/test_config_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/test_flow_text.dart';

class TestConfigScreen extends StatefulWidget {
  const TestConfigScreen({super.key});

  @override
  State<TestConfigScreen> createState() => _TestConfigScreenState();
}

class _TestConfigScreenState extends State<TestConfigScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<TestConfigProvider>();
      if (!provider.loaded) {
        provider.load().then((_) async {
          if (!mounted) return;
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getBool('sample_config_loaded') != true) {
            _loadSampleConfig();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final provider = context.watch<TestConfigProvider>();
    final theme = Theme.of(context);
    final apps = provider.apps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, provider),
        Expanded(
          child: apps.isEmpty
              ? _buildEmptyState(context)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (provider.currentApp != null)
                      _buildCurrentAppCard(context, provider.currentApp!),
                    if (provider.apps.isNotEmpty && provider.currentApp == null)
                      _buildNoSelectionCard(context, provider),
                    const SizedBox(height: 12),
                    Text(
                      tr('testConfigAppList'),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ...apps.map((app) => _buildAppCard(context, provider, app)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, TestConfigProvider provider) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('testConfigCenter'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('testConfigCenterHint'),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _showAppConfigDialog(context, provider, null),
            icon: const Icon(Icons.add, size: 16),
            label: Text(tr('newAppConfig')),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _importJson,
            icon: const Icon(Icons.upload_file, size: 16),
            label: Text(tr('importJsonConfig')),
          ),
          const SizedBox(width: 8),
          if (provider.apps.isNotEmpty)
            TextButton.icon(
              onPressed: () => _confirmClear(context, provider),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(tr('clearConfig')),
            ),
          const SizedBox(width: 8),
          if (provider.apps.isNotEmpty)
            IconButton(
              onPressed: _exportAllConfigs,
              icon: const Icon(Icons.ios_share, size: 16),
              tooltip: tr('exportConfigsTooltip'),
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _exportSample,
            icon: const Icon(Icons.download, size: 16),
            tooltip: tr('exportSampleConfig'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              tr('noTestConfig'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              tr('noTestConfigHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _importJson,
                  icon: const Icon(Icons.upload_file),
                  label: Text(tr('importJsonConfig')),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _loadSampleConfig,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: Text(tr('loadSampleConfig')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentAppCard(BuildContext context, TestAppConfig app) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(90)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('currentTestApp'),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  app.displayName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(app.packageName, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.read<TestConfigProvider>().deselectApp(),
            icon: const Icon(Icons.close, size: 14),
            label: Text(tr('deselectCurrentApp'),
                style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSelectionCard(
      BuildContext context, TestConfigProvider provider) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              color: theme.colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('noCurrentApp'),
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(
      BuildContext context, TestConfigProvider provider, TestAppConfig app) {
    final theme = Theme.of(context);
    final isCurrent = provider.currentApp?.id == app.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.apps,
                    size: 18,
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app.displayName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (isCurrent)
                  Chip(
                    label: Text(tr('current')),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  TextButton(
                    onPressed: app.id == null
                        ? null
                        : () => provider.selectApp(app.id!),
                    child: Text(tr('setCurrentTestApp')),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _showAppConfigDialog(context, provider, app),
                  icon: const Icon(Icons.edit, size: 16),
                  tooltip: tr('editAppConfig'),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: app.id == null
                      ? null
                      : () => _copyAppConfig(context, provider, app.id!),
                  icon: const Icon(Icons.content_copy, size: 16),
                  tooltip: tr('copyAppConfig'),
                  visualDensity: VisualDensity.compact,
                ),
                if (!isCurrent)
                  IconButton(
                    onPressed: () => _deleteAppConfig(context, provider, app),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    tooltip: tr('deleteAppConfig'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(context, tr('testConfigPackageName'), app.packageName),
            if (app.logcat.keywords.isNotEmpty)
              _infoRow(context, tr('testConfigKeyword'),
                  app.logcat.keywords.join('、')),
            if (app.logcat.tags.isNotEmpty)
              _infoRow(context, tr('testConfigLogcatTag'),
                  app.logcat.tags.join('、')),
            if (app.filePaths.isNotEmpty)
              _infoRow(
                context,
                tr('testConfigCommonPaths'),
                app.filePaths.map((item) => item.name).join('、'),
              ),
            if (app.testTexts.isNotEmpty)
              _infoRow(
                context,
                tr('testConfigTexts'),
                app.testTexts.map(_displayTestText).join('、'),
              ),
            if (app.notes.trim().isNotEmpty)
              _infoRow(context, tr('testConfigNotes'), app.notes),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _displayTestText(TestNamedValue item) {
    if (!item.sensitive) return '${item.name}: ${item.value}';
    return '${item.name}: ******';
  }

  Future<void> _importJson() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json'])
      ],
    );
    if (file == null) return;
    try {
      final content = await File(file.path).readAsString();
      if (!mounted) return;
      final result = await context
          .read<TestConfigProvider>()
          .importFromJsonString(content);
      if (!mounted) return;
      final message = result.hasSensitiveValues
          ? tr('testConfigImportedWithSensitive', {
              'count': result.importedCount.toString(),
            })
          : tr('testConfigImported', {
              'count': result.importedCount.toString(),
            });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on TestConfigException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('importFailed')}: $e')),
      );
    }
  }

  Future<void> _confirmClear(
      BuildContext context, TestConfigProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(tr('clearConfig')),
        content: Text(tr('clearConfigConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await provider.clear();
    }
  }

  Future<void> _loadSampleConfig() async {
    const sampleJson = '''{
  "schemaVersion": 1,
  "configName": "示例 App 测试配置",
  "description": "导入后选中 App，Logcat/ADB指令/文件管理/测试会话会自动填入配置内容。",
  "apps": [
    {
      "id": "example-app",
      "appName": "示例 App",
      "packageName": "com.example.app",
      "appType": "Android",
      "notes": "请根据实际项目修改包名和其他信息",
      "logcat": {
        "keywords": ["Exception", "Error", "FATAL", "crash"],
        "tags": ["ExampleTag", "MyApp"],
        "defaultLevel": "W"
      },
      "deepLinks": [
        { "name": "首页", "url": "exampleapp://home" },
        { "name": "商品详情", "url": "exampleapp://product/detail?id=1" },
        { "name": "个人中心", "url": "exampleapp://profile" }
      ],
      "filePaths": [
        { "name": "下载目录", "path": "/storage/emulated/0/Download" },
        { "name": "App数据目录", "path": "/sdcard/Android/data/com.example.app" }
      ],
      "testTexts": [
        { "name": "测试手机号", "value": "13800000000" },
        { "name": "测试验证码", "value": "123456" }
      ],
      "testFlows": [
        {
          "name": "登录流程",
          "steps": [
            "1. 打开 App",
            "2. 点击登录按钮",
            "3. 输入手机号和验证码",
            "4. 点击确认登录",
            "5. 验证跳转到首页"
          ]
        }
      ]
    }
  ]
}''';
    try {
      await context.read<TestConfigProvider>().importFromJsonString(sampleJson);
      if (!mounted) return;
      await SharedPreferences.getInstance()
          .then((prefs) => prefs.setBool('sample_config_loaded', true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('sampleConfigLoaded'))),
      );
    } on TestConfigException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _exportSample() async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
      suggestedName: 'sample_test_config.json',
    );
    if (location == null) return;
    try {
      const sample = <String, dynamic>{
        'schemaVersion': 1,
        'configName': '示例 App 测试配置',
        'description': '导入后选中 App，Logcat/ADB指令/文件管理/测试会话会自动填入配置内容。',
        'apps': [
          {
            'id': 'example-app',
            'appName': '示例 App',
            'packageName': 'com.example.app',
            'appType': 'Android',
            'notes': '请根据实际项目修改包名和其他信息',
            'logcat': {
              'keywords': ['Exception', 'Error', 'FATAL', 'crash'],
              'tags': ['ExampleTag', 'MyApp'],
              'defaultLevel': 'W',
            },
            'deepLinks': [
              {'name': '首页', 'url': 'exampleapp://home'},
              {'name': '商品详情', 'url': 'exampleapp://product/detail?id=1'},
              {'name': '个人中心', 'url': 'exampleapp://profile'},
            ],
            'filePaths': [
              {'name': '下载目录', 'path': '/storage/emulated/0/Download'},
              {
                'name': 'App数据目录',
                'path': '/sdcard/Android/data/com.example.app',
              },
            ],
            'testTexts': [
              {'name': '测试手机号', 'value': '13800000000'},
              {'name': '测试验证码', 'value': '123456'},
            ],
            'testFlows': [
              {
                'name': '登录流程',
                'steps': [
                  '1. 打开 App',
                  '2. 点击登录按钮',
                  '3. 输入手机号和验证码',
                  '4. 点击确认登录',
                  '5. 验证跳转到首页',
                ],
              },
            ],
          },
        ],
      };
      final pretty = const JsonEncoder.withIndent('  ').convert(sample);
      await File(location.path).writeAsString(pretty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出到 ${location.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('exportFailed')}: $e')),
      );
    }
  }

  Future<void> _showAppConfigDialog(
    BuildContext context,
    TestConfigProvider provider,
    TestAppConfig? existing,
  ) async {
    final isEdit = existing != null;
    final nameCtrl =
        TextEditingController(text: isEdit ? existing.appName : '');
    final pkgCtrl =
        TextEditingController(text: isEdit ? existing.packageName : '');
    final typeCtrl =
        TextEditingController(text: isEdit ? existing.appType : '');
    final notesCtrl = TextEditingController(text: isEdit ? existing.notes : '');
    final kwCtrl = TextEditingController(
        text: isEdit ? existing.logcat.keywords.join(', ') : '');
    final tagCtrl = TextEditingController(
        text: isEdit ? existing.logcat.tags.join(', ') : '');
    var level = isEdit ? existing.logcat.defaultLevel : '';
    var showAdvanced = false;
    final deepLinksCtrl = TextEditingController(
        text: isEdit
            ? existing.deepLinks.map((d) => '${d.name}=${d.value}').join('\n')
            : '');
    final pathsCtrl = TextEditingController(
        text: isEdit
            ? existing.filePaths.map((p) => '${p.name}=${p.path}').join('\n')
            : '');
    final textsCtrl = TextEditingController(
        text: isEdit
            ? existing.testTexts.map((t) => '${t.name}=${t.value}').join('\n')
            : '');
    final flowsCtrl = TextEditingController(
        text: isEdit ? formatTestFlowText(existing.testFlows) : '');
    final safeCtrls = [
      nameCtrl,
      pkgCtrl,
      typeCtrl,
      notesCtrl,
      kwCtrl,
      tagCtrl,
      deepLinksCtrl,
      pathsCtrl,
      textsCtrl,
      flowsCtrl,
    ];

    final result = await showDialog<_AppConfigFormResult>(
      context: context,
      builder: (ctx) => _SafeDialog(
        controllers: safeCtrls,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
            title: Text(isEdit ? tr('editAppConfig') : tr('newAppConfig')),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(labelText: tr('appName')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pkgCtrl,
                      decoration:
                          InputDecoration(labelText: tr('appPackageName')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: typeCtrl,
                      decoration: InputDecoration(labelText: tr('appType')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration:
                          InputDecoration(labelText: tr('testConfigNotes')),
                    ),
                    InkWell(
                      onTap: () =>
                          setDialogState(() => showAdvanced = !showAdvanced),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              showAdvanced
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: Theme.of(ctx).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr('advancedOptions'),
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showAdvanced) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: kwCtrl,
                        decoration: InputDecoration(
                            labelText: tr('configLogcatKeywords')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tagCtrl,
                        decoration:
                            InputDecoration(labelText: tr('configLogcatTags')),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: level.isEmpty ? null : level,
                        decoration:
                            InputDecoration(labelText: tr('configLogcatLevel')),
                        items: ['', 'V', 'D', 'I', 'W', 'E', 'F']
                            .map((l) => DropdownMenuItem(
                                value: l,
                                child: Text(l.isEmpty ? tr('all') : l)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => level = v ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: deepLinksCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                            labelText: tr('configDeepLinks'),
                            hintText: '首页=myapp://home'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pathsCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                            labelText: tr('configFilePaths'),
                            hintText: '下载=/storage/emulated/0/Download'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: textsCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                            labelText: tr('configTestTexts'),
                            hintText: '手机号=13800000000'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: flowsCtrl,
                        maxLines: 8,
                        decoration: InputDecoration(
                          labelText: tr('configTestFlows'),
                          hintText: tr('configTestFlowsHint'),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  _AppConfigFormResult(
                    name: nameCtrl.text.trim(),
                    packageName: pkgCtrl.text.trim(),
                    appType: typeCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    keywords: kwCtrl.text.trim(),
                    tags: tagCtrl.text.trim(),
                    level: level,
                    deepLinks: deepLinksCtrl.text,
                    filePaths: pathsCtrl.text,
                    testTexts: textsCtrl.text,
                    testFlows: flowsCtrl.text,
                  ),
                ),
                child: Text(tr('saveConfig')),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    if (result.packageName.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('appPackageName'))),
      );
      return;
    }

    final id = isEdit ? existing.id : null;

    final deepLinks = _parseNamedValues(result.deepLinks);
    final filePaths = _parsePathValues(result.filePaths);
    final testTexts = _parseNamedValues(result.testTexts);

    final app = TestAppConfig(
      id: id,
      appName: result.name.isEmpty ? result.packageName : result.name,
      packageName: result.packageName,
      appType: result.appType,
      notes: result.notes,
      logcat: TestLogcatConfig(
        keywords: result.keywords
            .split(RegExp(r'[,，]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        tags: result.tags
            .split(RegExp(r'[,，]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        defaultLevel: result.level,
      ),
      deepLinks: deepLinks,
      filePaths: filePaths,
      testTexts: testTexts,
      testFlows: parseTestFlowText(result.testFlows),
    );

    await provider.createOrUpdateApp(app);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('configSaved'))),
    );
  }

  List<TestNamedValue> _parseNamedValues(String raw) {
    if (raw.trim().isEmpty) return const [];
    return raw.split('\n').where((line) => line.contains('=')).map((line) {
      final idx = line.indexOf('=');
      final name = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      return TestNamedValue(name: name, value: value);
    }).toList();
  }

  List<TestFilePathConfig> _parsePathValues(String raw) {
    if (raw.trim().isEmpty) return const [];
    return raw.split('\n').where((line) => line.contains('=')).map((line) {
      final idx = line.indexOf('=');
      final name = line.substring(0, idx).trim();
      final path = line.substring(idx + 1).trim();
      return TestFilePathConfig(name: name, path: path);
    }).toList();
  }

  Future<void> _deleteAppConfig(
    BuildContext context,
    TestConfigProvider provider,
    TestAppConfig app,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(tr('deleteAppConfig')),
        content: Text(tr('deleteAppConfigConfirm', {'name': app.displayName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
    if (ok == true) {
      final id = app.id;
      if (id != null) {
        await provider.deleteApp(id);
      }
    }
  }

  Future<void> _copyAppConfig(
    BuildContext context,
    TestConfigProvider provider,
    int appId,
  ) async {
    try {
      await provider.copyApp(appId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('configCopied'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('copyError')}: $e')),
      );
    }
  }

  Future<void> _exportAllConfigs() async {
    final provider = context.read<TestConfigProvider>();
    if (provider.apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('noConfigToExport'))),
      );
      return;
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
      suggestedName: 'test_configs_export.json',
    );
    if (location == null) return;
    try {
      final file = provider.exportAsConfigFile();
      final pretty = const JsonEncoder.withIndent('  ').convert(file.toJson());
      await File(location.path).writeAsString(pretty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('configsExported', {
            'count': file.apps.length.toString(),
            'path': location.path,
          })),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('exportFailed')}: $e')),
      );
    }
  }
}

class _SafeDialog extends StatefulWidget {
  final List<TextEditingController> controllers;
  final Widget Function(List<TextEditingController> ctrls) builder;

  const _SafeDialog({required this.controllers, required this.builder});

  @override
  State<_SafeDialog> createState() => _SafeDialogState();
}

class _SafeDialogState extends State<_SafeDialog> {
  @override
  void dispose() {
    for (final c in widget.controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.controllers);
}

class _AppConfigFormResult {
  final String name;
  final String packageName;
  final String appType;
  final String notes;
  final String keywords;
  final String tags;
  final String level;
  final String deepLinks;
  final String filePaths;
  final String testTexts;
  final String testFlows;

  const _AppConfigFormResult({
    required this.name,
    required this.packageName,
    required this.appType,
    required this.notes,
    required this.keywords,
    required this.tags,
    required this.level,
    required this.deepLinks,
    required this.filePaths,
    required this.testTexts,
    required this.testFlows,
  });
}
