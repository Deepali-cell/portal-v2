import 'package:flutter/foundation.dart';

@immutable
class Item {
  const Item({
    required this.name,
    required this.itemCode,
    required this.itemName,
    this.itemGroup,
    this.stockUom,
    this.isStockItem = true,
    this.disabled = false,
    this.image,
  });

  final String name;
  final String itemCode;
  final String itemName;
  final String? itemGroup;
  final String? stockUom;
  final bool isStockItem;
  final bool disabled;
  final String? image;

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        name: j['name'] as String,
        itemCode: (j['item_code'] ?? j['name']) as String,
        itemName: (j['item_name'] ?? '') as String,
        itemGroup: j['item_group'] as String?,
        stockUom: j['stock_uom'] as String?,
        isStockItem: (j['is_stock_item'] ?? 1) == 1,
        disabled: (j['disabled'] ?? 0) == 1,
        image: j['image'] as String?,
      );
}

@immutable
class ItemDetail {
  const ItemDetail({
    required this.name,
    required this.itemCode,
    required this.itemName,
    this.itemGroup,
    this.stockUom,
    this.isStockItem = true,
    this.isSalesItem = true,
    this.isPurchaseItem = true,
    this.description,
    this.disabled = false,
    this.image,
    this.valuationRate,
    this.standardRate,
    this.gstHsnCode,
  });

  final String name;
  final String itemCode;
  final String itemName;
  final String? itemGroup;
  final String? stockUom;
  final bool isStockItem;
  final bool isSalesItem;
  final bool isPurchaseItem;
  final String? description;
  final bool disabled;
  final String? image;
  final double? valuationRate;
  final double? standardRate;
  final String? gstHsnCode;

  factory ItemDetail.fromJson(Map<String, dynamic> j) => ItemDetail(
        name: j['name'] as String,
        itemCode: (j['item_code'] ?? j['name']) as String,
        itemName: (j['item_name'] ?? '') as String,
        itemGroup: j['item_group'] as String?,
        stockUom: j['stock_uom'] as String?,
        isStockItem: (j['is_stock_item'] ?? 1) == 1,
        isSalesItem: (j['is_sales_item'] ?? 1) == 1,
        isPurchaseItem: (j['is_purchase_item'] ?? 1) == 1,
        description: j['description'] as String?,
        disabled: (j['disabled'] ?? 0) == 1,
        image: j['image'] as String?,
        valuationRate: (j['valuation_rate'] as num?)?.toDouble(),
        standardRate: (j['standard_rate'] as num?)?.toDouble(),
        gstHsnCode: j['gst_hsn_code'] as String?,
      );
}
