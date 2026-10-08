import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/form_meta.dart';

class RecordsRepository {
  RecordsRepository(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> listDocs(
    String doctype, {
    String? search,
    int limit = 50,
  }) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalListDocs,
        queryParameters: {
          'doctype': doctype,
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': limit,
        },
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getDoc(String doctype, String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalGetDoc,
        queryParameters: {'doctype': doctype, 'name': name},
      );
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Current saved values of an existing record for the editable form fields
  /// (parent + child rows), so the Edit form can pre-fill. `getDoc` returns
  /// only the trimmed display fields, which is why edit needs this.
  Future<Map<String, dynamic>> getFormValues(
      String doctype, String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalFormValues,
        queryParameters: {'doctype': doctype, 'name': name},
      );
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<FormMeta> getFormMeta(String doctype) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalFormMeta,
        queryParameters: {'doctype': doctype},
      );
      return FormMeta.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Map<String, String>>> searchLink(String doctype,
      {String txt = ''}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalSearchLink,
        queryParameters: {'doctype': doctype, 'txt': txt, 'limit': 20},
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => {
                'value': (e['value'] ?? '').toString(),
                'label': (e['label'] ?? e['value'] ?? '').toString(),
              })
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Read source fields of a linked record so the form can auto-fill
  /// fetch_from fields when a Link is picked. Returns {field: value}.
  Future<Map<String, dynamic>> fetchLinkValues(
    String doctype,
    String name,
    List<String> fields,
  ) async {
    if (name.isEmpty || fields.isEmpty) return const {};
    try {
      final resp = await _dio.get(
        ApiPaths.portalFetchLink,
        queryParameters: {
          'doctype': doctype,
          'name': name,
          'fields': jsonEncode(fields),
        },
      );
      final msg = resp.data['message'];
      if (msg is Map) return msg.cast<String, dynamic>();
      return const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Insert (name null) or update, optionally submit. Returns {name, docstatus}.
  Future<Map<String, dynamic>> saveDoc(
    String doctype,
    Map<String, dynamic> values, {
    String? name,
    bool submit = false,
  }) async {
    try {
      final resp = await _dio.post(
        ApiPaths.portalSaveDoc,
        data: {
          'doctype': doctype,
          'values': jsonEncode(values),
          if (name != null) 'name': name,
          'submit': submit ? 1 : 0,
        },
      );
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Submit a draft (docstatus 0 -> 1). ERPNext submit permission applies.
  Future<void> submitDoc(String doctype, String name) async {
    try {
      await _dio.post(ApiPaths.portalSubmitDoc,
          data: {'doctype': doctype, 'name': name});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Cancel a submitted doc (docstatus 1 -> 2). ERPNext cancel permission applies.
  Future<void> cancelDoc(String doctype, String name) async {
    try {
      await _dio.post(ApiPaths.portalCancelDoc,
          data: {'doctype': doctype, 'name': name});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Which downstream docs already exist (draft or submitted) for a source doc.
  /// Returns {targetDoctype: {exists:0/1, count:int, sample:String?}}. Used to
  /// hide "Create ..." buttons once the next-step doc has been made.
  Future<Map<String, dynamic>> getCreatedTargets(
      String doctype, String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalCreatedTargets,
        queryParameters: {'doctype': doctype, 'name': name},
      );
      final msg = resp.data['message'];
      if (msg is Map) return msg.cast<String, dynamic>();
      return const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Delete a draft/cancelled doc. ERPNext delete permission + link checks apply.
  Future<void> deleteDoc(String doctype, String name) async {
    try {
      await _dio.post(ApiPaths.portalDeleteDoc,
          data: {'doctype': doctype, 'name': name});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final recordsRepositoryProvider = Provider<RecordsRepository>(
    (ref) => RecordsRepository(ref.watch(dioProvider)));
