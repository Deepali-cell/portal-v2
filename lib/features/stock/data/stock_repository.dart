import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class StockRepository {
  StockRepository(this._dio);
  final Dio _dio;

  Future<List<Item>> listItems({String? search, int limit = 50}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.stockListItems,
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': limit,
        },
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => Item.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Create a new Item. The backend runs Frappe's own create-permission
  /// check, so this throws (403) if the user lacks ERPNext "create" on Item.
  Future<Item> createItem({
    required String itemCode,
    String? itemName,
    String? itemGroup,
    String? stockUom,
    bool isStockItem = true,
    bool isSalesItem = true,
    bool isPurchaseItem = true,
    double? standardRate,
    String? description,
    String? gstHsnCode,
  }) async {
    try {
      final resp = await _dio.post(
        ApiPaths.stockCreateItem,
        data: {
          'item_code': itemCode,
          if (itemName != null && itemName.isNotEmpty) 'item_name': itemName,
          if (itemGroup != null) 'item_group': itemGroup,
          if (stockUom != null) 'stock_uom': stockUom,
          'is_stock_item': isStockItem ? 1 : 0,
          'is_sales_item': isSalesItem ? 1 : 0,
          'is_purchase_item': isPurchaseItem ? 1 : 0,
          if (standardRate != null) 'standard_rate': standardRate,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (gstHsnCode != null && gstHsnCode.isNotEmpty)
            'gst_hsn_code': gstHsnCode,
        },
      );
      return Item.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Update an existing Item. The backend runs Frappe's own write-permission
  /// check, so this throws (403) if the user lacks ERPNext "write" on Item.
  Future<ItemDetail> updateItem({
    required String name,
    String? itemName,
    String? itemGroup,
    String? stockUom,
    bool? isStockItem,
    bool? isSalesItem,
    bool? isPurchaseItem,
    double? standardRate,
    String? description,
    String? gstHsnCode,
  }) async {
    try {
      final resp = await _dio.post(
        ApiPaths.stockUpdateItem,
        data: {
          'name': name,
          if (itemName != null) 'item_name': itemName,
          if (itemGroup != null) 'item_group': itemGroup,
          if (stockUom != null) 'stock_uom': stockUom,
          if (isStockItem != null) 'is_stock_item': isStockItem ? 1 : 0,
          if (isSalesItem != null) 'is_sales_item': isSalesItem ? 1 : 0,
          if (isPurchaseItem != null)
            'is_purchase_item': isPurchaseItem ? 1 : 0,
          if (standardRate != null) 'standard_rate': standardRate,
          if (description != null) 'description': description,
          if (gstHsnCode != null) 'gst_hsn_code': gstHsnCode,
        },
      );
      return ItemDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Link-field options (Item Group, UOM…) via the generic, read-filtered
  /// portal endpoint. Returns [{value,label}].
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

  Future<ItemDetail> getItem(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.stockGetItem,
        queryParameters: {'name': name},
      );
      return ItemDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
