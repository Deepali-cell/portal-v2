import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';

@immutable
class PhoneLookupResult {
  const PhoneLookupResult({
    required this.matched,
    required this.normalizedQuery,
    this.type,
    this.name,
    this.displayName,
    this.status,
    this.owner,
    this.ownerFullName,
    this.daysSinceContact,
    this.image,
  });

  final bool matched;
  final String normalizedQuery;
  final String? type; // "Lead" or "Opportunity"
  final String? name;
  final String? displayName;
  final String? status;
  final String? owner;
  final String? ownerFullName;
  final int? daysSinceContact;
  final String? image;

  bool get isLead => type == 'Lead';
  bool get isDeal => type == 'Opportunity';

  factory PhoneLookupResult.fromJson(Map<String, dynamic> j) =>
      PhoneLookupResult(
        matched: j['matched'] == true,
        normalizedQuery: (j['normalized_query'] ?? '').toString(),
        type: j['type'] as String?,
        name: j['name'] as String?,
        displayName: j['display_name'] as String?,
        status: j['status'] as String?,
        owner: j['owner'] as String?,
        ownerFullName: j['owner_full_name'] as String?,
        daysSinceContact: (j['days_since_contact'] as num?)?.toInt(),
        image: j['image'] as String?,
      );
}

class PhoneLookupRepository {
  PhoneLookupRepository(this._dio);
  final Dio _dio;

  Future<PhoneLookupResult> lookup(String number) async {
    try {
      final resp = await _dio.get(
        ApiPaths.lookupByPhone,
        queryParameters: {'number': number},
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return PhoneLookupResult.fromJson(msg);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}
