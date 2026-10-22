import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:inventoryapp/database/app_database.dart';
import 'package:inventoryapp/database/database_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({
    super.key,
    required this.invoiceNumber,
    required this.saleDate,
    this.customerName = 'Walk-in Customer',
    required this.paymentMethod,
    required this.items,
    required this.subtotalFils,
    this.discountFils = 0,
    required this.totalFils,
  });

  final String invoiceNumber;
  final DateTime saleDate;
  final String customerName;
  final String paymentMethod;
  final List<Map<String, Object>> items;
  final int subtotalFils;
  final int discountFils;
  final int totalFils;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsFuture = ref.watch(appSettingsDaoProvider).getSettings();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Save invoice PDF to this PC',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _saveInvoice(context, settingsFuture),
          ),
          IconButton(
            tooltip: 'Print invoice',
            icon: const Icon(Icons.print),
            onPressed: () => _printInvoice(context, settingsFuture),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 760),
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FutureBuilder<AppSetting?>(
                            future: settingsFuture,
                            builder: (context, snapshot) =>
                                _brandBlock(snapshot.data),
                          ),
                          const SizedBox(height: 16),
                          _invoiceMeta(crossAlign: CrossAxisAlignment.start),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FutureBuilder<AppSetting?>(
                            future: settingsFuture,
                            builder: (context, snapshot) =>
                                _brandBlock(snapshot.data),
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 190,
                          child:
                              _invoiceMeta(crossAlign: CrossAxisAlignment.end),
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 36),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Customer',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    Text(
                      customerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Payment method',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    Text(
                      paymentMethod,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 10,
                  ),
                  color: const Color(0xFFF9FAFB),
                  child: const Row(
                    children: [
                      Expanded(flex: 4, child: Text('Product')),
                      Expanded(child: Text('Qty')),
                      Expanded(child: Text('Price')),
                      Expanded(child: Text('Line total')),
                    ],
                  ),
                ),
                ...items.map((item) {
                  final name = item['name'] as String;
                  final sku = item['sku'] as String;
                  final quantity = item['quantity'] as int;
                  final unitPrice = item['unitPrice'] as int;
                  final lineSubtotal = item['lineSubtotal'] as int;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$name${_itemVariant(item)}'),
                              Text(
                                sku,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: Text('$quantity')),
                        Expanded(child: Text(_money(unitPrice))),
                        Expanded(child: Text(_money(lineSubtotal))),
                      ],
                    ),
                  );
                }),
                const Divider(height: 28),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 280,
                    child: Column(
                      children: [
                        const Divider(height: 24),
                        _amountRow('Subtotal', subtotalFils),
                        if (discountFils > 0)
                          _amountRow('Discount', -discountFils),
                        _amountRow('Total', totalFils, bold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                FutureBuilder<AppSetting?>(
                  future: settingsFuture,
                  builder: (context, snapshot) {
                    final footer = snapshot.data?.invoiceFooter?.trim();
                    return Column(
                      children: [
                        Center(
                          child: Text(
                            footer == null || footer.isEmpty
                                ? 'Thank you for your business!'
                                : footer,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (footer == null || footer.isEmpty) ...[
                          const SizedBox(height: 5),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountRow(String label, int fils, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
          ),
          const Spacer(),
          Text(
            _money(fils),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _money(int amount) {
    return 'PKR $amount';
  }

  String _itemVariant(Map<String, Object> item) {
    final size = item['size'] as String? ?? '';
    final color = item['color'] as String? ?? '';
    final attributes = [
      if (size.isNotEmpty) 'Size $size',
      if (color.isNotEmpty) color,
    ];
    return attributes.isEmpty ? '' : ' · ${attributes.join(' / ')}';
  }

  Widget _brandBlock(AppSetting? settings) {
    final shopName = settings?.shopName.trim();
    final shopAddress = settings?.shopAddress?.trim();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: Image.asset(
              'assets/images/company_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.store_outlined,
                size: 58,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            shopName?.isNotEmpty == true ? shopName! : 'SR BRANDED BOUTIQUE',
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          if (shopAddress?.isNotEmpty == true)
            Text(shopAddress!, textAlign: TextAlign.center)
          else
            const Text('Pakistan', textAlign: TextAlign.center),
          if (settings?.shopPhoneNumber?.trim().isNotEmpty == true)
            Text(settings!.shopPhoneNumber!.trim(),
                textAlign: TextAlign.center),
          if (settings?.shopEmail?.trim().isNotEmpty == true)
            Text(settings!.shopEmail!.trim(), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _invoiceMeta({required CrossAxisAlignment crossAlign}) {
    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        const Text('INVOICE',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(invoiceNumber, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(_date(saleDate)),
      ],
    );
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _printInvoice(
    BuildContext context,
    Future<AppSetting?> settingsFuture,
  ) async {
    try {
      final settings = await settingsFuture;
      await Printing.layoutPdf(
        name: 'Invoice-$invoiceNumber.pdf',
        onLayout: (format) => _generatePdf(
          format,
          invoiceFooter: settings?.invoiceFooter,
          settings: settings,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not print invoice: $error')),
      );
    }
  }

  Future<void> _saveInvoice(
    BuildContext context,
    Future<AppSetting?> settingsFuture,
  ) async {
    try {
      final settings = await settingsFuture;
      final documents = await getApplicationDocumentsDirectory();
      final invoiceDirectory = Directory(
        p.join(documents.path, 'SR Branded Boutique', 'Invoices'),
      );
      await invoiceDirectory.create(recursive: true);
      final safeInvoiceNumber =
          invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final invoiceFile = File(
        p.join(invoiceDirectory.path, 'Invoice-$safeInvoiceNumber.pdf'),
      );
      final bytes = await _generatePdf(
        PdfPageFormat.a4,
        invoiceFooter: settings?.invoiceFooter,
        settings: settings,
      );
      await invoiceFile.writeAsBytes(bytes, flush: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice PDF saved to ${invoiceFile.path}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save invoice PDF: $error')),
      );
    }
  }

  Future<Uint8List> _generatePdf(
    PdfPageFormat format, {
    String? invoiceFooter,
    AppSetting? settings,
  }) async {
    final pdf = pw.Document();
    pw.MemoryImage? logo;
    try {
      final logoBytes =
          (await rootBundle.load('assets/images/company_logo.png'))
              .buffer
              .asUint8List();
      logo = pw.MemoryImage(logoBytes);
    } catch (_) {
      // Keep invoice printing usable if the asset bundle has not refreshed yet.
    }

    String pdfMoney(int amount) => 'PKR $amount';
    final shopName = settings?.shopName.trim();
    final shopAddress = settings?.shopAddress?.trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (context) => [
          pw.Center(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null) ...[
                  pw.Image(logo, width: 90, height: 90, fit: pw.BoxFit.contain),
                  pw.SizedBox(height: 10),
                ],
                pw.Text(
                  shopName?.isNotEmpty == true
                      ? shopName!
                      : 'SR BRANDED BOUTIQUE',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                if (shopAddress?.isNotEmpty == true)
                  pw.Text(shopAddress!, textAlign: pw.TextAlign.center)
                else
                  pw.Text('Pakistan', textAlign: pw.TextAlign.center),
                if (settings?.shopPhoneNumber?.trim().isNotEmpty == true)
                  pw.Text(settings!.shopPhoneNumber!.trim(),
                      textAlign: pw.TextAlign.center),
                if (settings?.shopEmail?.trim().isNotEmpty == true)
                  pw.Text(settings!.shopEmail!.trim(),
                      textAlign: pw.TextAlign.center),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'INVOICE',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text('Invoice: $invoiceNumber'),
          pw.Text('Date: ${_date(saleDate)}'),
          pw.Text('Customer: $customerName'),
          pw.Text('Payment method: $paymentMethod'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            data: [
              ['Product', 'SKU', 'Qty', 'Price', 'Line total'],
              ...items.map(
                (item) => [
                  '${item['name']}${_itemVariant(item)}',
                  item['sku'].toString(),
                  item['quantity'].toString(),
                  pdfMoney(item['unitPrice'] as int),
                  pdfMoney(item['lineSubtotal'] as int),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.SizedBox(height: 6),
                pw.Text('Subtotal: ${pdfMoney(subtotalFils)}'),
                if (discountFils > 0)
                  pw.Text('Discount: -${pdfMoney(discountFils)}'),
                pw.Text(
                  'Total: ${pdfMoney(totalFils)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Center(
            child: pw.Text(
              invoiceFooter?.trim().isNotEmpty == true
                  ? invoiceFooter!.trim()
                  : 'Thank you for your business!',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
