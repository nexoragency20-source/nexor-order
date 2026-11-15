import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'customer_models.dart';

Future<void> printCustomerStatement(CustomerStatement statement) async {
  final regular = await PdfGoogleFonts.notoNaskhArabicRegular();
  final bold = await PdfGoogleFonts.notoNaskhArabicBold();
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  pw.Widget cell(
    String value, {
    int flex = 1,
    bool isBold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.right,
  }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: pw.Text(
          value,
          textDirection: pw.TextDirection.rtl,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ),
    );
  }

  pw.Widget summaryItem(String title, String value) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(9),
      margin: const pw.EdgeInsets.symmetric(horizontal: 3),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: .5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            title,
            textDirection: pw.TextDirection.rtl,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  final customer = statement.customer;
  final generatedAt = DateFormat('yyyy/MM/dd - HH:mm').format(DateTime.now());
  final movements = statement.movements;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 34),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          'NEXOR ORDERS  •  ${context.pageNumber} / ${context.pagesCount}',
          textDirection: pw.TextDirection.ltr,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'NEXOR',
                    textDirection: pw.TextDirection.ltr,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple,
                    ),
                  ),
                  pw.Text(
                    'كشف حساب عميل',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.purple, thickness: 1.2),
              pw.SizedBox(height: 8),
              pw.Text(
                customer.name,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'الهاتف: ${customer.phone.isEmpty ? '—' : customer.phone}     البريد: ${customer.email.isEmpty ? '—' : customer.email}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'العنوان: ${customer.address.isEmpty ? '—' : customer.address}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'تاريخ إصدار الكشف: $generatedAt',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Row(
                children: [
                  summaryItem(
                    'إجمالي المشتريات',
                    _money(customer.totalPurchasesSyp),
                  ),
                  summaryItem('إجمالي المدفوع', _money(customer.paidSyp)),
                  summaryItem(
                    customer.balanceSyp >= 0 ? 'المتبقي عليه' : 'رصيد دائن',
                    _money(customer.balanceSyp.abs()),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'الحركة المالية',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 7),
              pw.Container(
                color: PdfColors.purple,
                child: pw.Row(
                  children: [
                    cell(
                      'التاريخ',
                      flex: 2,
                      isBold: true,
                      color: PdfColors.white,
                    ),
                    cell(
                      'البيان',
                      flex: 4,
                      isBold: true,
                      color: PdfColors.white,
                    ),
                    cell(
                      'المرجع',
                      flex: 2,
                      isBold: true,
                      color: PdfColors.white,
                    ),
                    cell('مدين', flex: 2, isBold: true, color: PdfColors.white),
                    cell('دائن', flex: 2, isBold: true, color: PdfColors.white),
                    cell(
                      'الرصيد',
                      flex: 2,
                      isBold: true,
                      color: PdfColors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...movements.map(
          (movement) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: .45),
                ),
              ),
              child: pw.Row(
                children: [
                  cell(DateFormat('yyyy/MM/dd').format(movement.date), flex: 2),
                  cell(movement.title, flex: 4),
                  cell(movement.reference, flex: 2),
                  cell(
                    movement.debitSyp > 0 ? _money(movement.debitSyp) : '—',
                    flex: 2,
                  ),
                  cell(
                    movement.creditSyp > 0 ? _money(movement.creditSyp) : '—',
                    flex: 2,
                    color: PdfColors.green,
                  ),
                  cell(_money(movement.balanceAfterSyp), flex: 2, isBold: true),
                ],
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            customer.balanceSyp >= 0
                ? 'الرصيد النهائي المستحق على العميل: ${_money(customer.balanceSyp)}'
                : 'رصيد دائن لصالح العميل: ${_money(customer.balanceSyp.abs())}',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple,
            ),
          ),
        ),
        if (customer.notes.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(
              'ملاحظات: ${customer.notes}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ],
    ),
  );

  final bytes = await pdf.save();
  final safeName = customer.name.replaceAll(
    RegExp(r'[^\w\u0600-\u06FF-]+'),
    '_',
  );
  await Printing.layoutPdf(
    name: 'NEXOR-Customer-Statement-$safeName.pdf',
    onLayout: (_) async => bytes,
  );
}

String _money(double value) => '${NumberFormat('#,##0.##').format(value)} ل.س';
