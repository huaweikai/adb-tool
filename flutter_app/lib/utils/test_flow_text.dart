import '../models/test_config.dart';

List<TestFlowConfig> parseTestFlowText(String input) {
  final flows = <TestFlowConfig>[];
  String currentName = '';
  final currentSteps = <String>[];

  void flush() {
    final name = currentName.trim();
    final steps = currentSteps
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
    if (name.isNotEmpty || steps.isNotEmpty) {
      flows.add(TestFlowConfig(
        name: name.isEmpty ? '测试流程 ${flows.length + 1}' : name,
        steps: steps,
      ));
    }
    currentName = '';
    currentSteps.clear();
  }

  for (final rawLine in input.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }
    final normalized = line.replaceFirst(RegExp(r'^[\-•*]\s*'), '').trim();
    final numbered =
        normalized.replaceFirst(RegExp(r'^\d+[\.、)]\s*'), '').trim();
    if ((line.endsWith('：') || line.endsWith(':')) && numbered.length > 1) {
      flush();
      currentName = line.substring(0, line.length - 1).trim();
    } else if (currentName.isEmpty && currentSteps.isEmpty) {
      currentName = numbered;
    } else {
      currentSteps.add(numbered);
    }
  }
  flush();

  return flows.where((flow) => flow.steps.isNotEmpty).toList();
}

String formatTestFlowText(List<TestFlowConfig> flows) {
  return flows
      .where((flow) => flow.steps.any((step) => step.trim().isNotEmpty))
      .map((flow) {
    final lines = <String>['${flow.name}：'];
    lines.addAll(flow.steps
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .map((step) => '- $step'));
    return lines.join('\n');
  }).join('\n\n');
}
