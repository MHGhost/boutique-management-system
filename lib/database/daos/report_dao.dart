import 'package:drift/drift.dart';

import '../app_database.dart';

class SaleReturnReportRow {
  const SaleReturnReportRow({
    required this.returnNumber,
    required this.invoiceNumber,
    required this.productId,
    required this.productName,
    required this.productSize,
    required this.productColor,
    required this.unitSellingPrice,
    required this.unitPurchasePrice,
    required this.returnType,
    required this.quantity,
    required this.restocked,
    required this.refundAmount,
    required this.vatAmount,
    required this.replacementAmount,
    required this.replacementVatAmount,
    required this.replacementProductId,
    required this.replacementPurchaseCost,
    required this.settlementAmount,
    required this.settlementMethod,
    required this.reason,
    required this.createdAt,
    required this.replacementProductName,
    required this.replacementProductSize,
    required this.replacementProductColor,
  });

  final String returnNumber;
  final String invoiceNumber;
  final int productId;
  final String productName;
  final String? productSize;
  final String? productColor;
  final int unitSellingPrice;
  final int unitPurchasePrice;
  final String returnType;
  final int quantity;
  final bool restocked;
  final int refundAmount;
  final int vatAmount;
  final int replacementAmount;
  final int replacementVatAmount;
  final int? replacementProductId;
  final int replacementPurchaseCost;
  final int settlementAmount;
  final String? settlementMethod;
  final String reason;
  final DateTime createdAt;
  final String? replacementProductName;
  final String? replacementProductSize;
  final String? replacementProductColor;

  factory SaleReturnReportRow.fromRow(QueryRow row) => SaleReturnReportRow(
        returnNumber: row.read<String>('return_number'),
        invoiceNumber: row.read<String>('invoice_number'),
        productId: row.read<int>('product_id'),
        productName: row.read<String>('product_name'),
        productSize: row.read<String?>('product_size'),
        productColor: row.read<String?>('product_color'),
        unitSellingPrice: row.read<int>('unit_selling_price'),
        unitPurchasePrice: row.read<int>('unit_purchase_price'),
        returnType: row.read<String>('return_type'),
        quantity: row.read<int>('quantity'),
        restocked: row.read<int>('restocked') != 0,
        refundAmount: row.read<int>('refund_amount'),
        vatAmount: row.read<int>('vat_amount'),
        replacementAmount: row.read<int>('replacement_amount'),
        replacementVatAmount: row.read<int>('replacement_vat_amount'),
        replacementProductId: row.read<int?>('replacement_product_id'),
        replacementPurchaseCost: row.read<int>('replacement_purchase_cost'),
        settlementAmount: row.read<int>('settlement_amount'),
        settlementMethod: row.read<String?>('settlement_method'),
        reason: row.read<String>('reason'),
        createdAt: DateTime.parse(row.read<String>('created_at')),
        replacementProductName: row.read<String?>('replacement_product_name'),
        replacementProductSize: row.read<String?>('replacement_product_size'),
        replacementProductColor: row.read<String?>('replacement_product_color'),
      );
}

/// Read-only aggregate views used by the reporting screens.
class ReportDao extends DatabaseAccessor<AppDatabase> {
  ReportDao(super.attachedDatabase);

  static const _returnsQuery = '''
    SELECT r.return_number, s.invoice_number, r.product_id,
      p.name AS product_name, p.size AS product_size, p.color AS product_color,
      si.selling_price AS unit_selling_price,
      si.purchase_price AS unit_purchase_price,
      r.return_type, r.quantity, r.restocked, r.refund_amount,
      CASE WHEN si.quantity = 0 THEN 0
        ELSE (si.vat_amount * r.quantity + si.quantity / 2) / si.quantity
      END AS vat_amount,
      r.replacement_amount,
      CASE WHEN si.vat_amount > 0 AND r.replacement_amount > 0
        THEN r.replacement_amount - CAST(
          (r.replacement_amount * 10000 + 5500) / 11000 AS INTEGER)
        ELSE 0
      END AS replacement_vat_amount,
      r.settlement_amount, r.settlement_method,
      r.reason, r.created_at, r.replacement_product_id,
      r.replacement_purchase_cost,
      rp.name AS replacement_product_name,
      rp.size AS replacement_product_size, rp.color AS replacement_product_color
    FROM sales_returns r
    INNER JOIN sales s ON s.id = r.sale_id
    INNER JOIN sales_items si ON si.id = r.sale_item_id
    INNER JOIN products p ON p.id = r.product_id
    LEFT JOIN products rp ON rp.id = r.replacement_product_id
  ''';

  Stream<List<SaleReturnReportRow>> watchSaleReturns() => customSelect(
        '$_returnsQuery ORDER BY r.created_at DESC, r.id DESC',
        // processReturn updates sales (and sometimes products) in the same
        // transaction, which invalidates this stream after inserting the raw
        // sales_returns row.
        readsFrom: {
          attachedDatabase.sales,
          attachedDatabase.salesItems,
          attachedDatabase.products,
        },
      ).watch().map((rows) => rows.map(SaleReturnReportRow.fromRow).toList());
}
