import 'package:flutter/foundation.dart';

@immutable
class TaskItem {
  const TaskItem({
    required this.name,
    required this.subject,
    required this.status,
    required this.priority,
    this.project,
    this.expEndDate,
    this.progress = 0,
    this.assignees = const [],
  });

  final String name;
  final String subject;
  final String status;
  final String priority;
  final String? project;
  final DateTime? expEndDate;
  final double progress;
  final List<String> assignees;

  bool get isDone => status == 'Completed' || status == 'Cancelled';

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        name: j['name'] as String,
        subject: (j['subject'] ?? '') as String,
        status: (j['status'] ?? 'Open') as String,
        priority: (j['priority'] ?? 'Medium') as String,
        project: j['project'] as String?,
        expEndDate: j['exp_end_date'] != null
            ? DateTime.tryParse(j['exp_end_date'].toString())
            : null,
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        assignees: ((j['assignees'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

@immutable
class TaskDetail {
  const TaskDetail({
    required this.name,
    required this.subject,
    required this.status,
    required this.priority,
    this.description,
    this.project,
    this.expEndDate,
    this.progress = 0,
    this.assignees = const [],
  });
  final String name;
  final String subject;
  final String status;
  final String priority;
  final String? description;
  final String? project;
  final DateTime? expEndDate;
  final double progress;
  final List<String> assignees;

  factory TaskDetail.fromJson(Map<String, dynamic> j) => TaskDetail(
        name: j['name'] as String,
        subject: (j['subject'] ?? '') as String,
        status: (j['status'] ?? 'Open') as String,
        priority: (j['priority'] ?? 'Medium') as String,
        description: j['description'] as String?,
        project: j['project'] as String?,
        expEndDate: j['exp_end_date'] != null
            ? DateTime.tryParse(j['exp_end_date'].toString())
            : null,
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        assignees: ((j['assignees'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

@immutable
class ProjectRef {
  const ProjectRef({required this.name, required this.label});
  final String name;
  final String label;

  factory ProjectRef.fromJson(Map<String, dynamic> j) => ProjectRef(
        name: j['name'] as String,
        label: (j['project_name'] ?? j['name']) as String,
      );
}

@immutable
class TaskContext {
  const TaskContext({
    required this.tasks,
    required this.projects,
    required this.priorities,
    required this.statuses,
  });

  final List<TaskItem> tasks;
  final List<ProjectRef> projects;
  final List<String> priorities;
  final List<String> statuses;

  factory TaskContext.fromJson(Map<String, dynamic> j) => TaskContext(
        tasks: ((j['tasks'] as List?) ?? [])
            .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        projects: ((j['projects'] as List?) ?? [])
            .map((e) => ProjectRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        priorities:
            ((j['priorities'] as List?) ?? []).map((e) => e.toString()).toList(),
        statuses:
            ((j['statuses'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}
