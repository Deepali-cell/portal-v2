import 'package:flutter/material.dart';

/// One node of a module's flow diagram (e.g. "Quotations" in the Sales cycle).
///
/// Rendered by [FlowDiagram] as a tappable stage card showing a live [count]
/// and an optional monetary [value]. [route] deep-links to that stage's list
/// screen when tapped.
@immutable
class FlowStage {
  const FlowStage({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.value = 0,
    this.route,
    this.hint,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  /// Monetary total for the stage (0 when the doctype carries no value).
  final double value;

  /// List route to open when the stage is tapped (null = not tappable).
  final String? route;

  /// Optional one-word conversion hint shown on the connector below (e.g.
  /// "convert", "fulfil"). Purely descriptive.
  final String? hint;
}

/// Backend payload for a module's flow (currently only the Sales cycle needs a
/// server round-trip; the CRM flow is derived from the sales dashboard).
@immutable
class ModuleFlow {
  const ModuleFlow({required this.module, required this.stages});
  final String module;
  final List<FlowStageData> stages;

  factory ModuleFlow.fromJson(Map<String, dynamic> j) => ModuleFlow(
    module: (j['module'] ?? '').toString(),
    stages: ((j['stages'] as List?) ?? [])
        .map((e) => FlowStageData.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// Raw (icon/colour as strings) stage data straight from the backend. The
/// presentation layer maps [icon]/[color] into Flutter types.
@immutable
class FlowStageData {
  const FlowStageData({
    required this.label,
    required this.count,
    required this.value,
    required this.icon,
    required this.color,
    this.route,
  });

  final String label;
  final int count;
  final double value;
  final String icon;
  final String color;
  final String? route;

  factory FlowStageData.fromJson(Map<String, dynamic> j) => FlowStageData(
    label: (j['label'] ?? '').toString(),
    count: (j['count'] as num?)?.toInt() ?? 0,
    value: (j['value'] as num?)?.toDouble() ?? 0,
    icon: (j['icon'] ?? '').toString(),
    color: (j['color'] ?? '').toString(),
    route: j['route'] as String?,
  );
}
