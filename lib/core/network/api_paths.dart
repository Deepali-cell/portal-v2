/// Frappe REST/RPC endpoint paths used by the app.
class ApiPaths {
  ApiPaths._();

  // Tenant resolution (middleware on `TCB_MIDDLEWARE_URL`, NOT the tenant's
  // own ERPNext). Called only on login to look up the tenant's server URL
  // and brand colours by Company ID.
  static const String tenantResolve =
      '/api/method/tcb_portal_control.api.tenant.resolve';

  // Today's Plan - salesperson's daily command-centre payload
  static const String todaysPlan =
      '/api/method/tcb_portal_erp.api.todays_plan.get_today_plan';

  // Post-call outcome capture (Phase A.4)
  static const String callLogOutcome =
      '/api/method/tcb_portal_erp.api.crm_calls.log_outcome';

  // Manager leaderboard (Phase A.7)
  static const String leaderboard =
      '/api/method/tcb_portal_erp.api.leaderboard.get_leaderboard';

  // Lookup CRM Lead / Deal by phone number (Phase D.1)
  static const String lookupByPhone =
      '/api/method/tcb_portal_erp.api.call_lookup.lookup_by_phone';

  // CRM pipeline / funnel dashboard (Runo R.14)
  static const String leadPipeline =
      '/api/method/tcb_portal_erp.api.pipeline.get_lead_pipeline';
  static const String dealPipeline =
      '/api/method/tcb_portal_erp.api.pipeline.get_deal_pipeline';

  // Sales performance scorecard (replaces the funnel screen). Per-person +
  // team activity for a month / year window.
  static const String performance =
      '/api/method/tcb_portal_erp.api.performance.get_performance';

  // Manufacturing dashboard (BOM -> Work Order -> Job Card flow + counters)
  static const String manufacturingDashboard =
      '/api/method/tcb_portal_erp.api.manufacturing.get_dashboard';

  // Manager-only live team status (Runo R.6)
  static const String teamStatus =
      '/api/method/tcb_portal_erp.api.team_status.get_team_status';

  // Sales dashboard (Phase L.6)
  static const String salesDashboard =
      '/api/method/tcb_portal_erp.api.dashboard.get_sales_dashboard';
  // Sales module flow (Customer -> Quotation -> SO -> Delivery -> Invoice)
  static const String salesCycle =
      '/api/method/tcb_portal_erp.api.dashboard.get_sales_cycle';
  // Purchase module flow (Material Request -> RFQ -> SQ -> PO -> Receipt)
  static const String purchaseCycle =
      '/api/method/tcb_portal_erp.api.dashboard.get_purchase_cycle';

  // Role-specific home sections - one endpoint per role. Each takes a
  // `period` (today | week | month | custom) and optional from_date/to_date.
  static const String hrDashboard =
      '/api/method/tcb_portal_erp.api.hr_dashboard.get_summary';
  // Employees on approved leave on a given date (default today).
  static const String hrOnLeaveList =
      '/api/method/tcb_portal_erp.api.hr_dashboard.on_leave_list';
  static const String projectsDashboard =
      '/api/method/tcb_portal_erp.api.projects_dashboard.get_summary';
  static const String accountsDashboard =
      '/api/method/tcb_portal_erp.api.accounts_dashboard.get_summary';

  // Live location tracking (Phase LOC.1)
  static const String locSetTrackingEnabled =
      '/api/method/tcb_portal_erp.api.location_tracking.set_tracking_enabled';
  static const String locTrackingStatus =
      '/api/method/tcb_portal_erp.api.location_tracking.get_tracking_status';
  static const String locRecordPing =
      '/api/method/tcb_portal_erp.api.location_tracking.record_ping';
  static const String locRecordPingsBatch =
      '/api/method/tcb_portal_erp.api.location_tracking.record_pings_batch';
  static const String locRecordHeartbeat =
      '/api/method/tcb_portal_erp.api.location_tracking.record_heartbeat';
  static const String locMyTeamLive =
      '/api/method/tcb_portal_erp.api.location_tracking.my_team_live';
  static const String locPersonCurrent =
      '/api/method/tcb_portal_erp.api.location_tracking.person_current';
  static const String locPersonTrail =
      '/api/method/tcb_portal_erp.api.location_tracking.person_trail';

  // Call recording + AI pipeline (Phase D.2.4 + D.2.5)
  static const String uploadRecording =
      '/api/method/tcb_portal_erp.api.call_intelligence.upload_recording';
  /// Idempotency lookup - used by the mobile after a multipart-upload
  /// DioException to confirm whether the server already saved the row
  /// (Cloudflare 524 / mobile network drop after server commit).
  static const String findRecordingByClientId =
      '/api/method/tcb_portal_erp.api.call_intelligence.find_by_client_id';
  /// Always-log endpoint - mobile calls this for every detected call
  /// (connected or not) so the user has a complete call history even
  /// when no OEM recording is produced. Auto-matches to a Lead/Deal.
  static const String logCallAttempt =
      '/api/method/tcb_portal_erp.api.call_intelligence.log_call_attempt';
  static const String getRecording =
      '/api/method/tcb_portal_erp.api.call_intelligence.get_recording';
  static const String listRecordingsFor =
      '/api/method/tcb_portal_erp.api.call_intelligence.list_recordings_for';
  /// Global "Recordings" screen: every recording the caller can see (own, or
  /// all if admin/HR). Not scoped to a Lead/Deal.
  static const String listMyRecordings =
      '/api/method/tcb_portal_erp.api.call_intelligence.list_my_recordings';
  /// Fetches one recording's audio bytes (base64) through an authenticated
  /// request, since recordings are private files a bare URL can't stream.
  static const String downloadRecording =
      '/api/method/tcb_portal_erp.api.call_intelligence.download_recording';
  static const String applySuggestedStatus =
      '/api/method/tcb_portal_erp.api.call_intelligence.apply_suggested_status';

  // Auth
  static const String login = '/api/method/login';
  static const String logout = '/api/method/logout';
  static const String credentials =
      '/api/method/tcb_portal_erp.api.auth.get_credentials';
  static const String revokeCredentials =
      '/api/method/tcb_portal_erp.api.auth.revoke_credentials';
  static const String profile =
      '/api/method/tcb_portal_erp.api.auth.get_profile';
  static const String profileUpdate =
      '/api/method/tcb_portal_erp.api.auth.update_my_profile';

  // Directory
  static const String directoryList =
      '/api/method/tcb_portal_erp.api.directory.list_employees';

  // Invoices
  static const String invoicesContext =
      '/api/method/tcb_portal_erp.api.invoices.get_context';
  static const String customerSearch =
      '/api/method/tcb_portal_erp.api.invoices.search_customers';
  static const String supplierSearch =
      '/api/method/tcb_portal_erp.api.invoices.search_suppliers';
  static const String itemSearch =
      '/api/method/tcb_portal_erp.api.invoices.search_items';
  static const String salesInvoiceCreate =
      '/api/method/tcb_portal_erp.api.invoices.create_sales_invoice';
  static const String purchaseInvoiceCreate =
      '/api/method/tcb_portal_erp.api.invoices.create_purchase_invoice';
  static const String invoiceDetail =
      '/api/method/tcb_portal_erp.api.invoices.get_invoice_detail';
  static const String invoiceSubmit =
      '/api/method/tcb_portal_erp.api.invoices.submit_invoice';
  static const String modesOfPayment =
      '/api/method/tcb_portal_erp.api.invoices.list_modes_of_payment';
  static const String recordPayment =
      '/api/method/tcb_portal_erp.api.invoices.record_payment';
  static const String paymentsList =
      '/api/method/tcb_portal_erp.api.invoices.list_payments';

  // Attendance
  static const String attendanceContext =
      '/api/method/tcb_portal_erp.api.attendance.get_context';
  static const String attendanceMark =
      '/api/method/tcb_portal_erp.api.attendance.mark';
  // Attendance calendar / history / HR management
  static const String attendanceMonthly =
      '/api/method/tcb_portal_erp.api.attendance_report.get_monthly';
  static const String attendanceDayLogs =
      '/api/method/tcb_portal_erp.api.attendance_report.get_day_logs';
  static const String attendanceRoster =
      '/api/method/tcb_portal_erp.api.attendance_report.list_attendance';
  static const String attendanceMarkStatus =
      '/api/method/tcb_portal_erp.api.attendance_report.mark_attendance';
  static const String attendancePending =
      '/api/method/tcb_portal_erp.api.attendance_report.get_pending_attendance';

  // Leave
  static const String leaveContext =
      '/api/method/tcb_portal_erp.api.leave.get_context';
  static const String leaveApply = '/api/method/tcb_portal_erp.api.leave.apply';
  static const String compOffApply =
      '/api/method/tcb_portal_erp.api.leave.apply_comp_off';

  // Expenses
  static const String expenseContext =
      '/api/method/tcb_portal_erp.api.expense.get_context';
  static const String expenseApply =
      '/api/method/tcb_portal_erp.api.expense.apply';
  static const String expenseAddAttachment =
      '/api/method/tcb_portal_erp.api.expense.add_claim_attachment';
  static const String expenseClaimDetail =
      '/api/method/tcb_portal_erp.api.expense.get_claim_detail';
  static const String expensePendingApprovals =
      '/api/method/tcb_portal_erp.api.expense.get_pending_approvals';
  static const String expenseActOnClaim =
      '/api/method/tcb_portal_erp.api.expense.act_on_claim';
  static const String expenseAllClaims =
      '/api/method/tcb_portal_erp.api.expense.get_all_claims';
  // Download one claim attachment (base64) through the authenticated API,
  // because private /private/files URLs 403 in an external browser.
  static const String expenseDownloadAttachment =
      '/api/method/tcb_portal_erp.api.expense.download_attachment';

  // Comp-Off (Compensatory Leave Request) approvals
  static const String compOffDetail =
      '/api/method/tcb_portal_erp.api.leave.get_comp_off_detail';
  static const String compOffPendingApprovals =
      '/api/method/tcb_portal_erp.api.leave.get_comp_off_pending_approvals';
  static const String compOffActOnRequest =
      '/api/method/tcb_portal_erp.api.leave.act_on_comp_off';
  // Every comp-off request in a window (HR/admin see all; others their own).
  static const String compOffAll =
      '/api/method/tcb_portal_erp.api.leave.get_all_comp_off';

  // Leave notice-period policy (HR-configurable rules)
  static const String leaveNoticeRulesList =
      '/api/method/tcb_portal_erp.api.leave_policy.list_notice_rules';
  static const String leaveNoticeRuleSave =
      '/api/method/tcb_portal_erp.api.leave_policy.save_notice_rule';
  static const String leaveNoticeRuleDelete =
      '/api/method/tcb_portal_erp.api.leave_policy.delete_notice_rule';

  // Work From Home (Attendance Request, reason "Work From Home")
  static const String wfhApply =
      '/api/method/tcb_portal_erp.api.wfh.apply_wfh';
  static const String wfhMyRequests =
      '/api/method/tcb_portal_erp.api.wfh.get_my_wfh';
  static const String wfhDetail =
      '/api/method/tcb_portal_erp.api.wfh.get_wfh_detail';
  static const String wfhPendingApprovals =
      '/api/method/tcb_portal_erp.api.wfh.get_wfh_pending_approvals';
  static const String wfhActOnRequest =
      '/api/method/tcb_portal_erp.api.wfh.act_on_wfh';

  // Payslips
  static const String payslipList =
      '/api/method/tcb_portal_erp.api.payslip.get_list';
  static const String payslipDetail =
      '/api/method/tcb_portal_erp.api.payslip.get_detail';
  static const String payslipAllList =
      '/api/method/tcb_portal_erp.api.payslip.get_all_list';

  // Tasks
  static const String taskContext =
      '/api/method/tcb_portal_erp.api.task.get_context';
  static const String taskCreate = '/api/method/tcb_portal_erp.api.task.create';
  static const String taskSetStatus =
      '/api/method/tcb_portal_erp.api.task.set_status';
  static const String taskListByProject =
      '/api/method/tcb_portal_erp.api.task.list_by_project';
  static const String taskAssign = '/api/method/tcb_portal_erp.api.task.assign';
  static const String taskUnassign =
      '/api/method/tcb_portal_erp.api.task.unassign';

  // Projects (team/assignment; the Project doc itself is generic - see
  // portalListDocs/portalGetDoc/portalSaveDoc below)
  static const String projectTeam =
      '/api/method/tcb_portal_erp.api.project.get_team';
  static const String projectAddMember =
      '/api/method/tcb_portal_erp.api.project.add_member';
  static const String projectRemoveMember =
      '/api/method/tcb_portal_erp.api.project.remove_member';

  // Timesheet
  static const String timesheetContext =
      '/api/method/tcb_portal_erp.api.timesheet.get_context';
  static const String timesheetListAll =
      '/api/method/tcb_portal_erp.api.timesheet.list_all';
  static const String timesheetDetail =
      '/api/method/tcb_portal_erp.api.timesheet.get_detail';
  static const String timesheetCreate =
      '/api/method/tcb_portal_erp.api.timesheet.create';
  static const String timesheetSubmit =
      '/api/method/tcb_portal_erp.api.timesheet.submit_timesheet';
  static const String timesheetAddLog =
      '/api/method/tcb_portal_erp.api.timesheet.add_log';
  static const String timesheetUpdateLog =
      '/api/method/tcb_portal_erp.api.timesheet.update_log';
  static const String timesheetDeleteLog =
      '/api/method/tcb_portal_erp.api.timesheet.delete_log';
  static const String activeTimer =
      '/api/method/tcb_portal_erp.api.timesheet.get_active_timer';
  static const String timerStart =
      '/api/method/tcb_portal_erp.api.timesheet.start_timer';
  static const String timerStop =
      '/api/method/tcb_portal_erp.api.timesheet.stop_timer';
  static const String projectTasks =
      '/api/method/tcb_portal_erp.api.timesheet.get_project_tasks';

  // CRM Leads
  static const String leadsContext =
      '/api/method/tcb_portal_erp.api.leads.get_context';
  static const String leadDetail =
      '/api/method/tcb_portal_erp.api.leads.get_detail';
  static const String leadCreate = '/api/method/tcb_portal_erp.api.leads.create';
  static const String leadUpdate = '/api/method/tcb_portal_erp.api.leads.update';
  // Sales flow (2026-09-28): Lead → Opportunity → Customer.
  // Step 1 — a Lead is converted into an ERPNext Opportunity.
  static const String leadConvert =
      '/api/method/tcb_portal_erp.api.leads.convert_to_opportunity';

  // CRM Deals (ERPNext Opportunity)
  static const String dealsContext =
      '/api/method/tcb_portal_erp.api.deals.get_context';
  static const String dealDetail =
      '/api/method/tcb_portal_erp.api.deals.get_detail';
  static const String dealUpdate = '/api/method/tcb_portal_erp.api.deals.update';
  // Step 2 — an Opportunity is converted into an ERPNext Customer (unlocking
  // Quotation → Sales Order → Sales Invoice).
  static const String dealConvert =
      '/api/method/tcb_portal_erp.api.deals.convert_to_customer';

  // File upload
  static const String uploadFile = '/api/method/upload_file';

  // Push notifications (device token registration)
  static const String registerDevice =
      '/api/method/tcb_portal_erp.api.notifications.register_device';
  static const String unregisterDevice =
      '/api/method/tcb_portal_erp.api.notifications.unregister_device';

  // In-app notifications (powered by Frappe's Notification Log)
  static const String notificationsList =
      '/api/method/tcb_portal_erp.api.notifications.list_notifications';
  static const String notificationsUnreadCount =
      '/api/method/tcb_portal_erp.api.notifications.unread_count';
  static const String notificationMarkRead =
      '/api/method/tcb_portal_erp.api.notifications.mark_as_read';
  static const String notificationsMarkAllRead =
      '/api/method/tcb_portal_erp.api.notifications.mark_all_read';

  // Leave detail
  static const String leaveApplicationDetail =
      '/api/method/tcb_portal_erp.api.leave.get_application_detail';
  static const String leavePendingApprovals =
      '/api/method/tcb_portal_erp.api.leave.get_pending_approvals';
  static const String leaveActOnApplication =
      '/api/method/tcb_portal_erp.api.leave.act_on_application';
  // Every leave application in a window (HR/admin see all; others their own).
  static const String leaveAllApplications =
      '/api/method/tcb_portal_erp.api.leave.get_all_applications';
  // Download one leave attachment (base64) through the authenticated API.
  static const String leaveDownloadAttachment =
      '/api/method/tcb_portal_erp.api.leave.download_attachment';

  // Task detail + update
  static const String taskDetail =
      '/api/method/tcb_portal_erp.api.task.get_detail';
  static const String taskUpdate =
      '/api/method/tcb_portal_erp.api.task.update';

  // Payslip PDF
  static const String payslipDownloadPdf =
      '/api/method/tcb_portal_erp.api.payslip.download_pdf';

  // CRM collaboration (Notes / Tasks / Comments / Attachments / Assignees)
  static const String notesList = '/api/method/tcb_portal_erp.api.notes.list_notes';
  static const String noteCreate = '/api/method/tcb_portal_erp.api.notes.create_note';
  static const String noteUpdate = '/api/method/tcb_portal_erp.api.notes.update_note';
  static const String noteDelete = '/api/method/tcb_portal_erp.api.notes.delete_note';

  // WhatsApp conversation (Business Cloud API, or click-to-chat fallback).
  static const String whatsappMode =
      '/api/method/tcb_portal_erp.api.whatsapp_log.get_mode';
  static const String whatsappSend =
      '/api/method/tcb_portal_erp.api.whatsapp_log.send_message';
  static const String whatsappList =
      '/api/method/tcb_portal_erp.api.whatsapp_log.list_messages';
  static const String whatsappLog =
      '/api/method/tcb_portal_erp.api.whatsapp_log.log_message';
  static const String whatsappDelete =
      '/api/method/tcb_portal_erp.api.whatsapp_log.delete_message';

  // Internal team chat (staff-to-staff direct messages only).
  static const String chatChannels =
      '/api/method/tcb_portal_erp.api.team_chat.list_channels';
  static const String chatStartDirect =
      '/api/method/tcb_portal_erp.api.team_chat.start_direct';
  static const String chatMessages =
      '/api/method/tcb_portal_erp.api.team_chat.list_messages';
  static const String chatSend =
      '/api/method/tcb_portal_erp.api.team_chat.send_message';

  static const String crmTasksList =
      '/api/method/tcb_portal_erp.api.crm_tasks.list_tasks';
  static const String crmTaskCreate =
      '/api/method/tcb_portal_erp.api.crm_tasks.create_task';
  static const String crmTaskUpdate =
      '/api/method/tcb_portal_erp.api.crm_tasks.update_task';
  static const String crmTaskDelete =
      '/api/method/tcb_portal_erp.api.crm_tasks.delete_task';

  static const String commentsList =
      '/api/method/tcb_portal_erp.api.comments.list_comments';
  static const String commentCreate =
      '/api/method/tcb_portal_erp.api.comments.create_comment';
  static const String commentDelete =
      '/api/method/tcb_portal_erp.api.comments.delete_comment';

  static const String attachmentsList =
      '/api/method/tcb_portal_erp.api.attachments.list_attachments';
  static const String attachmentDelete =
      '/api/method/tcb_portal_erp.api.attachments.delete_attachment';

  static const String assigneesList =
      '/api/method/tcb_portal_erp.api.assignments.list_assignees';
  static const String assigneeAdd =
      '/api/method/tcb_portal_erp.api.assignments.add_assignee';
  static const String assigneeRemove =
      '/api/method/tcb_portal_erp.api.assignments.remove_assignee';
  static const String userSearch =
      '/api/method/tcb_portal_erp.api.assignments.search_assignable_users';

  // CRM Calls (CRM Call Log)
  static const String crmCallsList =
      '/api/method/tcb_portal_erp.api.crm_calls.list_calls';
  static const String crmCallCreate =
      '/api/method/tcb_portal_erp.api.crm_calls.create_call';
  static const String crmCallDelete =
      '/api/method/tcb_portal_erp.api.crm_calls.delete_call';

  // Emails (Communication) - list + compose+send
  static const String emailsList =
      '/api/method/tcb_portal_erp.api.emails.list_emails';
  static const String emailSend =
      '/api/method/tcb_portal_erp.api.emails.send_email';

  // Outgoing email (SMTP) setup - portal self-serve (System Manager only)
  static const String emailSettingsGet =
      '/api/method/tcb_portal_erp.api.email_settings.get_email_settings';
  static const String emailSettingsSave =
      '/api/method/tcb_portal_erp.api.email_settings.save_email_settings';
  static const String emailSettingsTest =
      '/api/method/tcb_portal_erp.api.email_settings.send_test_email';

  // Events (calendar)
  static const String eventsList =
      '/api/method/tcb_portal_erp.api.events.list_events';
  static const String eventCreate =
      '/api/method/tcb_portal_erp.api.events.create_event';
  static const String eventUpdate =
      '/api/method/tcb_portal_erp.api.events.update_event';
  static const String eventDelete =
      '/api/method/tcb_portal_erp.api.events.delete_event';

  // Activity timeline (aggregated)
  static const String timelineGet =
      '/api/method/tcb_portal_erp.api.timeline.get_timeline';

  // Administrator (in-app Frappe role-permission manager)
  static const String adminMeta =
      '/api/method/tcb_portal_erp.api.admin.get_admin_meta';
  static const String adminRoleMatrix =
      '/api/method/tcb_portal_erp.api.admin.get_role_matrix';
  static const String adminSetPerm =
      '/api/method/tcb_portal_erp.api.admin.set_role_perm';
  // Administrator - per-role access to the curated reports
  // Read-only health check of the site's set-up (apps, workflows, employees...).
  static const String adminSetupCheck =
      '/api/method/tcb_portal_erp.api.setup_check.get_setup_check';
  // Module licence (TCB) + per-site screen switches (Admin > Screens).
  static const String adminScreenConfig =
      '/api/method/tcb_portal_erp.api.portal_modules.get_config';
  static const String adminSetDisabledScreens =
      '/api/method/tcb_portal_erp.api.portal_modules.set_disabled_screens';
  // In-app integrations (WhatsApp, AI, push) — Admin > Integrations.
  static const String adminIntegrations =
      '/api/method/tcb_portal_erp.api.integrations.get_integrations';
  static const String adminSaveIntegration =
      '/api/method/tcb_portal_erp.api.integrations.save_integration';
  static const String adminTestIntegration =
      '/api/method/tcb_portal_erp.api.integrations.test_integration';
  static const String adminClearIntegration =
      '/api/method/tcb_portal_erp.api.integrations.clear_integration';
  static const String adminUploadPushAccount =
      '/api/method/tcb_portal_erp.api.integrations.upload_push_service_account';
  static const String adminReportMeta =
      '/api/method/tcb_portal_erp.api.admin.get_report_admin_meta';
  static const String adminReportRoles =
      '/api/method/tcb_portal_erp.api.admin.get_report_roles';
  static const String adminSetReportRole =
      '/api/method/tcb_portal_erp.api.admin.set_report_role';

  // Reports (curated standard ERPNext reports, per-report role gated)
  static const String reportsList =
      '/api/method/tcb_portal_erp.api.reports.list_reports';
  static const String reportRun =
      '/api/method/tcb_portal_erp.api.reports.run_report';

  // Generic portal records (Manufacturing, HR, Sales, Purchase…)
  static const String portalListDocs =
      '/api/method/tcb_portal_erp.api.portal_docs.list_docs';
  static const String portalGetDoc =
      '/api/method/tcb_portal_erp.api.portal_docs.get_doc';
  // Generic metadata-driven forms
  static const String portalFormMeta =
      '/api/method/tcb_portal_erp.api.portal_forms.get_meta';
  static const String portalFormValues =
      '/api/method/tcb_portal_erp.api.portal_forms.get_doc_values';
  static const String portalSearchLink =
      '/api/method/tcb_portal_erp.api.portal_forms.search_link';
  static const String portalFetchLink =
      '/api/method/tcb_portal_erp.api.portal_forms.fetch_link_values';
  static const String portalSaveDoc =
      '/api/method/tcb_portal_erp.api.portal_forms.save_doc';
  static const String portalSubmitDoc =
      '/api/method/tcb_portal_erp.api.portal_forms.submit_doc';
  static const String portalCancelDoc =
      '/api/method/tcb_portal_erp.api.portal_forms.cancel_doc';
  static const String portalDeleteDoc =
      '/api/method/tcb_portal_erp.api.portal_forms.delete_doc';
  static const String portalCreatedTargets =
      '/api/method/tcb_portal_erp.api.portal_forms.get_created_targets';

  // Purchase cycle conversions (PR -> RFQ -> SQ -> PO -> GRN -> PI -> Return)
  static const String purchaseCreateRfqFromMr =
      '/api/method/tcb_portal_erp.api.purchase.create_rfq_from_material_request';
  static const String purchaseRfqsForMr =
      '/api/method/tcb_portal_erp.api.purchase.list_rfqs_for_material_request';
  static const String purchaseRfqSuppliers =
      '/api/method/tcb_portal_erp.api.purchase.list_rfq_suppliers';
  static const String purchaseReceiptItems =
      '/api/method/tcb_portal_erp.api.purchase.list_receipt_items';
  static const String purchaseCreateSqFromRfq =
      '/api/method/tcb_portal_erp.api.purchase.create_supplier_quotation_from_rfq';
  static const String purchaseCompareQuotations =
      '/api/method/tcb_portal_erp.api.purchase.compare_quotations';
  static const String purchaseCreatePoFromSq =
      '/api/method/tcb_portal_erp.api.purchase.create_po_from_supplier_quotation';
  static const String purchasePosForSq =
      '/api/method/tcb_portal_erp.api.purchase.list_pos_for_supplier_quotation';
  static const String purchaseCreateReceiptFromPo =
      '/api/method/tcb_portal_erp.api.purchase.create_receipt_from_po';
  static const String purchaseCreateInvoiceFromPo =
      '/api/method/tcb_portal_erp.api.purchase.create_invoice_from_po';
  static const String purchaseCreateInvoiceFromReceipt =
      '/api/method/tcb_portal_erp.api.purchase.create_invoice_from_receipt';
  static const String purchaseCreateReturn =
      '/api/method/tcb_portal_erp.api.purchase.create_purchase_return';

  // Sales cycle conversions (Quotation -> SO -> DN -> Invoice -> Return)
  static const String salesCreateSoFromQuotation =
      '/api/method/tcb_portal_erp.api.sales.create_so_from_quotation';
  static const String salesCreateDeliveryNoteFromSo =
      '/api/method/tcb_portal_erp.api.sales.create_delivery_note_from_so';
  static const String salesCreateInvoiceFromSo =
      '/api/method/tcb_portal_erp.api.sales.create_invoice_from_so';
  static const String salesCreateInvoiceFromDeliveryNote =
      '/api/method/tcb_portal_erp.api.sales.create_invoice_from_delivery_note';
  static const String salesCreateReturn =
      '/api/method/tcb_portal_erp.api.sales.create_sales_return';
  static const String salesCreatePaymentEntryFromSo =
      '/api/method/tcb_portal_erp.api.sales.create_payment_entry_from_so';

  // Manufacturing cycle conversions (BOM -> Work Order -> Stock Entry)
  static const String mfgCreateWorkOrderFromBom =
      '/api/method/tcb_portal_erp.api.manufacturing.create_work_order_from_bom';
  static const String mfgCreateStockEntryFromWorkOrder =
      '/api/method/tcb_portal_erp.api.manufacturing.create_stock_entry_from_work_order';
  static const String mfgSubmitWorkOrder =
      '/api/method/tcb_portal_erp.api.manufacturing.submit_work_order';
  static const String mfgWorkOrderStockStatus =
      '/api/method/tcb_portal_erp.api.manufacturing.work_order_stock_status';
  static const String mfgCreateMaterialRequestFromWorkOrder =
      '/api/method/tcb_portal_erp.api.manufacturing.create_material_request_from_work_order';

  // Job Card shop-floor (list / detail / start / complete)
  static const String jobCardList =
      '/api/method/tcb_portal_erp.api.job_card.list_job_cards';
  static const String jobCardDetail =
      '/api/method/tcb_portal_erp.api.job_card.get_job_card';
  static const String jobCardStart =
      '/api/method/tcb_portal_erp.api.job_card.start_job_card';
  static const String jobCardComplete =
      '/api/method/tcb_portal_erp.api.job_card.complete_job_card';

  // Stock module (Phase 1)
  static const String stockListItems =
      '/api/method/tcb_portal_erp.api.stock.list_items';
  static const String stockGetItem =
      '/api/method/tcb_portal_erp.api.stock.get_item';
  static const String stockCreateItem =
      '/api/method/tcb_portal_erp.api.stock.create_item';
  static const String stockUpdateItem =
      '/api/method/tcb_portal_erp.api.stock.update_item';

  // Generic resource access
  static String resource(String doctype) => '/api/resource/$doctype';
  static String resourceItem(String doctype, String name) =>
      '/api/resource/$doctype/${Uri.encodeComponent(name)}';

  // RPC
  static String method(String dotted) => '/api/method/$dotted';
}
