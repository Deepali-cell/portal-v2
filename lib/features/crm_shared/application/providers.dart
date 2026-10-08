import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/crm_collab_repository.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

final crmCollabRepositoryProvider = Provider<CrmCollabRepository>(
  (ref) => CrmCollabRepository(ref.watch(dioProvider)),
);

final notesProvider = FutureProvider.family<List<CrmNote>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listNotes(key),
);

/// Whether WhatsApp goes through the company Business API (vs click-to-chat).
final whatsAppCloudProvider = FutureProvider<bool>(
  (ref) => ref.read(crmCollabRepositoryProvider).whatsAppCloudEnabled(),
);

final whatsAppProvider = FutureProvider.family<List<WhatsAppMessage>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listWhatsApp(key),
);

final crmTasksProvider = FutureProvider.family<List<CrmTaskItem>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listTasks(key),
);

final commentsProvider = FutureProvider.family<List<CrmComment>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listComments(key),
);

final attachmentsProvider = FutureProvider.family<List<CrmAttachment>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listAttachments(key),
);

final assigneesProvider = FutureProvider.family<List<CrmAssignee>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listAssignees(key),
);

final callsProvider = FutureProvider.family<List<CrmCall>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listCalls(key),
);

final emailsProvider = FutureProvider.family<List<CrmEmail>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listEmails(key),
);

final eventsProvider = FutureProvider.family<List<CrmEvent>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listEvents(key),
);

final timelineProvider = FutureProvider.family<List<TimelineEntry>, CrmRef>(
  (ref, key) => ref.read(crmCollabRepositoryProvider).listTimeline(key),
);
