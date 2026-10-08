import 'package:flutter/foundation.dart';

/// One field to render on a record detail screen.
@immutable
class FieldSpec {
  const FieldSpec(this.label, this.key, {this.isBool = false});
  final String label;
  final String key;
  final bool isBool;
}

/// Declarative description of a portal "records" screen backed by an
/// allowlisted ERP doctype (see portal_docs.py). Drives the generic
/// list + detail screens so a new module screen needs no bespoke widget.
@immutable
class RecordDescriptor {
  const RecordDescriptor({
    required this.key,
    required this.doctype,
    required this.cap,
    required this.title,
    required this.titleField,
    required this.subtitleFields,
    required this.detailFields,
  });

  /// Route-friendly id, e.g. 'mfg_bom'.
  final String key;

  /// ERP doctype, e.g. 'BOM'.
  final String doctype;

  /// Capability/screen key used for `profile.canDo(cap, action)`.
  final String cap;

  final String title;
  final String titleField;
  final List<String> subtitleFields;
  final List<FieldSpec> detailFields;
}

/// Central registry of record screens. Add a new entry + a nav destination and
/// the screen exists - no new widget code.
const Map<String, RecordDescriptor> recordRegistry = {
  // ---- Manufacturing ----
  'mfg_bom': RecordDescriptor(
    key: 'mfg_bom',
    doctype: 'BOM',
    cap: 'mfg_bom',
    title: 'BOM',
    titleField: 'item_name',
    subtitleFields: ['name', 'item'],
    detailFields: [
      FieldSpec('Item', 'item'),
      FieldSpec('Item Name', 'item_name'),
      FieldSpec('Quantity', 'quantity'),
      FieldSpec('UOM', 'uom'),
      FieldSpec('Active', 'is_active', isBool: true),
      FieldSpec('Default', 'is_default', isBool: true),
      FieldSpec('Total Cost', 'total_cost'),
    ],
  ),
  'mfg_work_order': RecordDescriptor(
    key: 'mfg_work_order',
    doctype: 'Work Order',
    cap: 'mfg_work_order',
    title: 'Work Orders',
    titleField: 'item_name',
    subtitleFields: ['name', 'status'],
    detailFields: [
      FieldSpec('Production Item', 'production_item'),
      FieldSpec('Item Name', 'item_name'),
      FieldSpec('Qty', 'qty'),
      FieldSpec('Produced', 'produced_qty'),
      FieldSpec('Status', 'status'),
      FieldSpec('BOM', 'bom_no'),
      FieldSpec('Planned Start', 'planned_start_date'),
      FieldSpec('Company', 'company'),
    ],
  ),
  'mfg_job_card': RecordDescriptor(
    key: 'mfg_job_card',
    doctype: 'Job Card',
    cap: 'mfg_job_card',
    title: 'Job Cards',
    titleField: 'operation',
    subtitleFields: ['name', 'status'],
    detailFields: [
      FieldSpec('Work Order', 'work_order'),
      FieldSpec('Operation', 'operation'),
      FieldSpec('Workstation', 'workstation'),
      FieldSpec('Status', 'status'),
      FieldSpec('For Qty', 'for_quantity'),
      FieldSpec('Completed', 'total_completed_qty'),
    ],
  ),
  'mfg_production_plan': RecordDescriptor(
    key: 'mfg_production_plan',
    doctype: 'Production Plan',
    cap: 'mfg_production_plan',
    title: 'Production Plan',
    titleField: 'name',
    subtitleFields: ['status', 'posting_date'],
    detailFields: [
      FieldSpec('Status', 'status'),
      FieldSpec('Posting Date', 'posting_date'),
      FieldSpec('Company', 'company'),
      FieldSpec('Total Planned', 'total_planned_qty'),
    ],
  ),
  'mfg_workstation': RecordDescriptor(
    key: 'mfg_workstation',
    doctype: 'Workstation',
    cap: 'mfg_workstation',
    title: 'Workstations',
    titleField: 'workstation_name',
    subtitleFields: ['name', 'workstation_type'],
    detailFields: [
      FieldSpec('Name', 'workstation_name'),
      FieldSpec('Type', 'workstation_type'),
      FieldSpec('Hour Rate', 'hour_rate'),
      FieldSpec('Status', 'status'),
    ],
  ),
  // ---- Stock ----
  'stock_warehouse': RecordDescriptor(
    key: 'stock_warehouse',
    doctype: 'Warehouse',
    cap: 'stock_warehouse',
    title: 'Warehouses',
    titleField: 'warehouse_name',
    subtitleFields: ['name', 'company'],
    detailFields: [
      FieldSpec('Warehouse Name', 'warehouse_name'),
      FieldSpec('Company', 'company'),
      FieldSpec('Group', 'is_group', isBool: true),
      FieldSpec('Parent', 'parent_warehouse'),
      FieldSpec('Disabled', 'disabled', isBool: true),
    ],
  ),
  'stock_material_request': RecordDescriptor(
    key: 'stock_material_request',
    doctype: 'Material Request',
    cap: 'purchase_material_request',
    title: 'Material Request',
    titleField: 'name',
    subtitleFields: ['material_request_type', 'status'],
    detailFields: [
      FieldSpec('Type', 'material_request_type'),
      FieldSpec('Status', 'status'),
      FieldSpec('Date', 'transaction_date'),
      FieldSpec('Company', 'company'),
    ],
  ),
  // ---- Sales ----
  'sales_customer': RecordDescriptor(
    key: 'sales_customer',
    doctype: 'Customer',
    cap: 'sales_customer',
    title: 'Customers',
    titleField: 'customer_name',
    subtitleFields: ['name', 'customer_group'],
    detailFields: [
      FieldSpec('Customer Name', 'customer_name'),
      FieldSpec('Group', 'customer_group'),
      FieldSpec('Territory', 'territory'),
      FieldSpec('Type', 'customer_type'),
      FieldSpec('Disabled', 'disabled', isBool: true),
    ],
  ),
  'sales_quotation': RecordDescriptor(
    key: 'sales_quotation',
    doctype: 'Quotation',
    cap: 'sales_quotation',
    title: 'Quotations',
    titleField: 'name',
    subtitleFields: ['customer_name', 'status'],
    detailFields: [
      FieldSpec('Party Name', 'party_name'),
      FieldSpec('Customer Name', 'customer_name'),
      FieldSpec('Status', 'status'),
      FieldSpec('Date', 'transaction_date'),
      FieldSpec('Grand Total', 'grand_total'),
      FieldSpec('Currency', 'currency'),
    ],
  ),
  'sales_order': RecordDescriptor(
    key: 'sales_order',
    doctype: 'Sales Order',
    cap: 'sales_order',
    title: 'Sales Orders',
    titleField: 'name',
    subtitleFields: ['customer_name', 'status'],
    detailFields: [
      FieldSpec('Customer', 'customer'),
      FieldSpec('Customer Name', 'customer_name'),
      FieldSpec('Status', 'status'),
      FieldSpec('Date', 'transaction_date'),
      FieldSpec('Delivery Date', 'delivery_date'),
      FieldSpec('Grand Total', 'grand_total'),
      FieldSpec('Currency', 'currency'),
    ],
  ),
  'sales_delivery': RecordDescriptor(
    key: 'sales_delivery',
    doctype: 'Delivery Note',
    cap: 'sales_delivery',
    title: 'Delivery Notes',
    titleField: 'name',
    subtitleFields: ['customer_name', 'status'],
    detailFields: [
      FieldSpec('Customer', 'customer'),
      FieldSpec('Customer Name', 'customer_name'),
      FieldSpec('Status', 'status'),
      FieldSpec('Posting Date', 'posting_date'),
      FieldSpec('Grand Total', 'grand_total'),
      FieldSpec('Currency', 'currency'),
    ],
  ),
  // ---- Purchase ----
  'purchase_supplier': RecordDescriptor(
    key: 'purchase_supplier',
    doctype: 'Supplier',
    cap: 'purchase_supplier',
    title: 'Suppliers',
    titleField: 'supplier_name',
    subtitleFields: ['name', 'supplier_group'],
    detailFields: [
      FieldSpec('Supplier Name', 'supplier_name'),
      FieldSpec('Group', 'supplier_group'),
      FieldSpec('Type', 'supplier_type'),
      FieldSpec('Country', 'country'),
      FieldSpec('Disabled', 'disabled', isBool: true),
    ],
  ),
  'purchase_rfq': RecordDescriptor(
    key: 'purchase_rfq',
    doctype: 'Request for Quotation',
    cap: 'purchase_rfq',
    title: 'RFQs',
    titleField: 'name',
    subtitleFields: ['status', 'transaction_date'],
    detailFields: [
      FieldSpec('Status', 'status'),
      FieldSpec('Date', 'transaction_date'),
      FieldSpec('Company', 'company'),
    ],
  ),
  'purchase_supplier_quotation': RecordDescriptor(
    key: 'purchase_supplier_quotation',
    doctype: 'Supplier Quotation',
    cap: 'purchase_supplier_quotation',
    title: 'Supplier Quotations',
    titleField: 'name',
    subtitleFields: ['supplier_name', 'status'],
    detailFields: [
      FieldSpec('Supplier', 'supplier'),
      FieldSpec('Supplier Name', 'supplier_name'),
      FieldSpec('Status', 'status'),
      FieldSpec('Date', 'transaction_date'),
      FieldSpec('Grand Total', 'grand_total'),
      FieldSpec('Currency', 'currency'),
    ],
  ),
  'purchase_order': RecordDescriptor(
    key: 'purchase_order',
    doctype: 'Purchase Order',
    cap: 'purchase_order',
    title: 'Purchase Orders',
    titleField: 'name',
    subtitleFields: ['supplier_name', 'status'],
    detailFields: [
      FieldSpec('Supplier', 'supplier'),
      FieldSpec('Supplier Name', 'supplier_name'),
      FieldSpec('Status', 'status'),
      FieldSpec('Date', 'transaction_date'),
      FieldSpec('Schedule Date', 'schedule_date'),
      FieldSpec('Grand Total', 'grand_total'),
      FieldSpec('Currency', 'currency'),
    ],
  ),
  'purchase_receipt': RecordDescriptor(
    key: 'purchase_receipt',
    doctype: 'Purchase Receipt',
    cap: 'purchase_receipt',
    title: 'Goods Receipt (GRN)',
    titleField: 'name',
    subtitleFields: ['supplier_name', 'status'],
    detailFields: [
      FieldSpec('Supplier', 'supplier'),
      FieldSpec('Supplier Name', 'supplier_name'),
      FieldSpec('Status', 'status'),
      FieldSpec('Posting Date', 'posting_date'),
      FieldSpec('Grand Total', 'grand_total'),
      FieldSpec('Currency', 'currency'),
    ],
  ),
  'stock_entry': RecordDescriptor(
    key: 'stock_entry',
    doctype: 'Stock Entry',
    cap: 'stock_entry',
    title: 'Stock Entry',
    titleField: 'name',
    subtitleFields: ['stock_entry_type', 'posting_date'],
    detailFields: [
      FieldSpec('Type', 'stock_entry_type'),
      FieldSpec('Purpose', 'purpose'),
      FieldSpec('Posting Date', 'posting_date'),
      FieldSpec('Company', 'company'),
    ],
  ),
  // ---- HR ----
  'hr_employee': RecordDescriptor(
    key: 'hr_employee',
    doctype: 'Employee',
    cap: 'hr_employee',
    title: 'Employees',
    titleField: 'employee_name',
    subtitleFields: ['name', 'designation'],
    detailFields: [
      FieldSpec('Employee Name', 'employee_name'),
      FieldSpec('Designation', 'designation'),
      FieldSpec('Department', 'department'),
      FieldSpec('Status', 'status'),
      FieldSpec('Company', 'company'),
      FieldSpec('Mobile', 'cell_number'),
      FieldSpec('Email', 'company_email'),
      FieldSpec('Date of Joining', 'date_of_joining'),
    ],
  ),
  'hr_shift_type': RecordDescriptor(
    key: 'hr_shift_type',
    doctype: 'Shift Type',
    cap: 'hr_shift_type',
    title: 'Shift Types',
    titleField: 'name',
    subtitleFields: ['start_time', 'end_time'],
    detailFields: [
      FieldSpec('Start Time', 'start_time'),
      FieldSpec('End Time', 'end_time'),
      FieldSpec('Auto Attendance', 'enable_auto_attendance', isBool: true),
      FieldSpec('Half-day Hours', 'working_hours_threshold_for_half_day'),
    ],
  ),
  'hr_shift_assignment': RecordDescriptor(
    key: 'hr_shift_assignment',
    doctype: 'Shift Assignment',
    cap: 'hr_shift_assignment',
    title: 'Shift Assignments',
    titleField: 'employee_name',
    subtitleFields: ['shift_type', 'start_date'],
    detailFields: [
      FieldSpec('Employee', 'employee_name'),
      FieldSpec('Shift', 'shift_type'),
      FieldSpec('Start Date', 'start_date'),
      FieldSpec('End Date', 'end_date'),
      FieldSpec('Status', 'status'),
      FieldSpec('Company', 'company'),
    ],
  ),
  'hr_holiday_list': RecordDescriptor(
    key: 'hr_holiday_list',
    doctype: 'Holiday List',
    cap: 'hr_holiday_list',
    title: 'Holiday Lists',
    titleField: 'holiday_list_name',
    subtitleFields: ['from_date', 'to_date'],
    detailFields: [
      FieldSpec('Name', 'holiday_list_name'),
      FieldSpec('From', 'from_date'),
      FieldSpec('To', 'to_date'),
      FieldSpec('Total Holidays', 'total_holidays'),
      FieldSpec('Weekly Off', 'weekly_off'),
    ],
  ),
  'hr_leave_policy': RecordDescriptor(
    key: 'hr_leave_policy',
    doctype: 'Leave Policy',
    cap: 'hr_leave_policy',
    title: 'Leave Policies',
    titleField: 'title',
    subtitleFields: ['name'],
    detailFields: [
      FieldSpec('Title', 'title'),
    ],
  ),
  'hr_leave_policy_assignment': RecordDescriptor(
    key: 'hr_leave_policy_assignment',
    doctype: 'Leave Policy Assignment',
    cap: 'hr_leave_policy_assignment',
    title: 'Leave Policy Assignment',
    titleField: 'employee_name',
    subtitleFields: ['leave_policy', 'effective_from'],
    detailFields: [
      FieldSpec('Employee', 'employee'),
      FieldSpec('Employee Name', 'employee_name'),
      FieldSpec('Leave Policy', 'leave_policy'),
      FieldSpec('Effective From', 'effective_from'),
      FieldSpec('Effective To', 'effective_to'),
      FieldSpec('Company', 'company'),
    ],
  ),
  'hr_leave_allocation': RecordDescriptor(
    key: 'hr_leave_allocation',
    doctype: 'Leave Allocation',
    cap: 'hr_leave_allocation',
    title: 'Leave Allocation',
    titleField: 'employee_name',
    subtitleFields: ['leave_type', 'total_leaves_allocated'],
    detailFields: [
      FieldSpec('Employee', 'employee'),
      FieldSpec('Employee Name', 'employee_name'),
      FieldSpec('Leave Type', 'leave_type'),
      FieldSpec('From', 'from_date'),
      FieldSpec('To', 'to_date'),
      FieldSpec('New Leaves', 'new_leaves_allocated'),
      FieldSpec('Total Allocated', 'total_leaves_allocated'),
      FieldSpec('Company', 'company'),
    ],
  ),
  'hr_holiday_assignment': RecordDescriptor(
    key: 'hr_holiday_assignment',
    doctype: 'Holiday List Assignment',
    cap: 'hr_holiday_assignment',
    title: 'Holiday Assignments',
    titleField: 'holiday_list',
    subtitleFields: ['assigned_to', 'from_date'],
    detailFields: [
      FieldSpec('Holiday List', 'holiday_list'),
      FieldSpec('Applicable For', 'applicable_for'),
      FieldSpec('Assigned To', 'assigned_to'),
      FieldSpec('Employee Name', 'employee_name'),
      FieldSpec('Starts From', 'from_date'),
    ],
  ),
  // ---- Projects ----
  'projects_project': RecordDescriptor(
    key: 'projects_project',
    doctype: 'Project',
    cap: 'projects_project',
    title: 'Projects',
    titleField: 'project_name',
    subtitleFields: ['name', 'status'],
    detailFields: [
      FieldSpec('Project Name', 'project_name'),
      FieldSpec('Customer', 'customer'),
      FieldSpec('Status', 'status'),
      FieldSpec('Priority', 'priority'),
      FieldSpec('Progress %', 'percent_complete'),
      FieldSpec('Start Date', 'expected_start_date'),
      FieldSpec('End Date', 'expected_end_date'),
      FieldSpec('Department', 'department'),
      FieldSpec('Company', 'company'),
    ],
  ),
};

/// Args passed to the shared detail route.
@immutable
class RecordArgs {
  const RecordArgs(this.descriptor, this.name);
  final RecordDescriptor descriptor;
  final String name;
}
