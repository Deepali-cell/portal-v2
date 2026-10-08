import 'package:flutter/foundation.dart';

@immutable
class MfgWorkOrderCounts {
  const MfgWorkOrderCounts({
    this.draft = 0,
    this.notStarted = 0,
    this.inProcess = 0,
    this.stopped = 0,
    this.completed = 0,
  });
  final int draft;
  final int notStarted;
  final int inProcess;
  final int stopped;
  final int completed;

  factory MfgWorkOrderCounts.fromJson(Map<String, dynamic> j) =>
      MfgWorkOrderCounts(
        draft: (j['draft'] as num?)?.toInt() ?? 0,
        notStarted: (j['not_started'] as num?)?.toInt() ?? 0,
        inProcess: (j['in_process'] as num?)?.toInt() ?? 0,
        stopped: (j['stopped'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class MfgJobCardCounts {
  const MfgJobCardCounts({
    this.open = 0,
    this.wip = 0,
    this.materialTransferred = 0,
    this.completed = 0,
  });
  final int open;
  final int wip;
  final int materialTransferred;
  final int completed;

  factory MfgJobCardCounts.fromJson(Map<String, dynamic> j) => MfgJobCardCounts(
        open: (j['open'] as num?)?.toInt() ?? 0,
        wip: (j['wip'] as num?)?.toInt() ?? 0,
        materialTransferred: (j['material_transferred'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class MfgRecentWorkOrder {
  const MfgRecentWorkOrder({
    required this.name,
    required this.itemLabel,
    required this.status,
    this.qty = 0,
    this.producedQty = 0,
  });
  final String name;
  final String itemLabel;
  final String status;
  final double qty;
  final double producedQty;

  double get progress => qty <= 0 ? 0 : (producedQty / qty).clamp(0.0, 1.0);

  factory MfgRecentWorkOrder.fromJson(Map<String, dynamic> j) =>
      MfgRecentWorkOrder(
        name: (j['name'] ?? '').toString(),
        itemLabel: (j['item_name'] ?? j['production_item'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
        producedQty: (j['produced_qty'] as num?)?.toDouble() ?? 0,
      );
}

@immutable
class ManufacturingDashboard {
  const ManufacturingDashboard({
    required this.activeBoms,
    required this.workOrders,
    required this.jobCards,
    required this.openWorkOrders,
    required this.openJobCards,
    required this.recentWorkOrders,
  });

  final int activeBoms;
  final MfgWorkOrderCounts workOrders;
  final MfgJobCardCounts jobCards;
  final int openWorkOrders;
  final int openJobCards;
  final List<MfgRecentWorkOrder> recentWorkOrders;

  factory ManufacturingDashboard.fromJson(Map<String, dynamic> j) =>
      ManufacturingDashboard(
        activeBoms: (j['active_boms'] as num?)?.toInt() ?? 0,
        workOrders: MfgWorkOrderCounts.fromJson(
            (j['work_orders'] as Map?)?.cast<String, dynamic>() ?? const {}),
        jobCards: MfgJobCardCounts.fromJson(
            (j['job_cards'] as Map?)?.cast<String, dynamic>() ?? const {}),
        openWorkOrders: (j['open_work_orders'] as num?)?.toInt() ?? 0,
        openJobCards: (j['open_job_cards'] as num?)?.toInt() ?? 0,
        recentWorkOrders: ((j['recent_work_orders'] as List?) ?? const [])
            .map((e) =>
                MfgRecentWorkOrder.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
