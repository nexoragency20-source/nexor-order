import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'finance_models.dart';

Future<void> printFinanceDailyReport(FinanceSnapshot snapshot) async {
  final regular = await PdfGoogleFonts.notoNaskhArabicRegular();
  final bold = await PdfGoogleFonts.notoNaskhArabicBold();
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final date = DateFormat('yyyy/MM/dd').format(
    DateTime.tryParse(snapshot.date) ?? DateTime.now(),
  );
  final summary = snapshot.summary;

  pw.Widget summaryItem(String title, String value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300, width: .5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(title, textDirection: pw.TextDirection.rtl,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 5),
              pw.Text(value, textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );

  pw.Widget cell(String value, {int flex = 1, bool boldText = false}) =>
      pw.Expanded(
        flex: flex,
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(
            value,
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: boldText ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(26, 28, 26, 34),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          'NEXOR FINANCE  •  ${context.pageNumber} / ${context.pagesCount}',
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
                  pw.Text('NEXOR', textDirection: pw.TextDirection.ltr,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                  pw.Text('تقرير الصندوق اليومي',
                      style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.deepPurple, thickness: 1.2),
              pw.SizedBox(height: 6),
              pw.Text('التاريخ: $date', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                'سعر الصرف المرجعي الحالي: ${_money(snapshot.exchangeRateSypPerUsd)} ل.س / USD',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 12),
              pw.Row(children: [
                summaryItem('رصيد الدولار النقدي', '${_money(summary.cashBalanceUsd)} USD'),
                summaryItem('رصيد الليرة النقدي', '${_money(summary.cashBalanceSyp)} ل.س'),
                summaryItem('مقبوضات اليوم', '${_money(summary.todayReceiptsUsdEquivalent)} USD مكافئ'),
                summaryItem('مدفوعات اليوم', '${_money(summary.todayPaymentsUsdEquivalent)} USD مكافئ'),
              ]),
              pw.SizedBox(height: 7),
              pw.Row(children: [
                summaryItem('صافي حركة اليوم', '${_money(summary.todayNetUsdEquivalent)} USD مكافئ'),
                summaryItem('عدد الحركات', '${summary.todayTransactionCount}'),
                summaryItem('تحويلات العملات', '${_money(summary.todayTransfersUsdEquivalent)} USD مكافئ'),
                summaryItem('الرصيد المكافئ', '${_money(summary.cashBalanceUsdEquivalent)} USD'),
              ]),
              pw.SizedBox(height: 16),
              pw.Text('تفاصيل الحركات', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Container(
                color: PdfColors.deepPurple,
                child: pw.Row(children: [
                  cell('الوقت', flex: 2, boldText: true),
                  cell('النوع', flex: 2, boldText: true),
                  cell('البيان', flex: 5, boldText: true),
                  cell('التصنيف', flex: 3, boldText: true),
                  cell('المبلغ', flex: 3, boldText: true),
                ]),
              ),
              ...snapshot.items.map((item) {
                final time = DateFormat('HH:mm').format(item.occurredAt);
                final amount = '${_money(item.amount)} ${item.currency == 'USD' ? 'USD' : 'ل.س'}';
                return pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .45)),
                  ),
                  child: pw.Row(children: [
                    cell(time, flex: 2),
                    cell(_typeLabel(item.type), flex: 2),
                    cell(item.description, flex: 5),
                    cell(item.category, flex: 3),
                    cell(amount, flex: 3, boldText: true),
                  ]),
                );
              }),
              if (snapshot.items.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(18),
                  child: pw.Center(child: pw.Text('لا توجد حركات مسجلة في هذا اليوم')),
                ),
              pw.SizedBox(height: 14),
              pw.Text(
                'تنبيه: التقرير يعرض الحركات النقدية فقط. مدفوعات البطاقة والتحويل البنكي لا تدخل في رصيد الصندوق.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final bytes = await pdf.save();
  await Printing.layoutPdf(
    name: 'NEXOR-Finance-Daily-$date.pdf',
    onLayout: (_) async => bytes,
  );
}

String _money(double value) => NumberFormat('#,##0.##').format(value);

String _typeLabel(String type) {
  switch (type) {
    case 'INCOME': return 'قبض';
    case 'EXPENSE': return 'دفع';
    case 'DEPOSIT': return 'إيداع';
    case 'WITHDRAWAL': return 'سحب';
    case 'OPENING_BALANCE': return 'رصيد افتتاحي';
    case 'TRANSFER_IN': return 'تحويل وارد';
    case 'TRANSFER_OUT': return 'تحويل صادر';
    default: return type;
  }
}
