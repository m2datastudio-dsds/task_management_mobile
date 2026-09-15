import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sub_activity.dart';
import '../models/task.dart';

class CompletionReportService {
  static Future<void> generate({
    required TaskItem task,
    required List<SubActivity> activities,
    required String organizationName,
    String? organizationAddress,
    required String assignedUserName,
  }) async {
    final document = pw.Document();
    final tableActivities =
        activities.where((item) => item.isTableFormat).toList();
    final columns = tableActivities.isEmpty
        ? <String>['Work Content']
        : tableActivities.first.tableColumns;
    final quantityIndex = columns.indexWhere((column) {
      final value = column.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return const {'qty', 'quantity', 'qtynumber', 'quantitynumber'}
          .contains(value);
    });
    final rows = tableActivities
        .map((item) => List<String>.generate(
            columns.length,
            (index) =>
                index < item.tableCells.length ? item.tableCells[index] : ''))
        .where((row) {
      if (quantityIndex < 0) return true;
      return (double.tryParse(row[quantityIndex].trim()) ?? 0) != 0;
    }).toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  organizationName,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if ((organizationAddress ?? '').trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    organizationAddress!.trim(),
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              '${task.bankName ?? 'Ticket'} - Work Completion Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 24),
          _detail('Ticket', task.title),
          _detail('Branch', task.bankBranchName ?? 'Not provided'),
          _detail('Assigned employee', assignedUserName),
          _detail(
              'Date of commencement', _date(task.pickedUpAt ?? task.createdAt)),
          _detail('Date of work completion',
              _date(task.completedAt ?? task.updatedAt)),
          if ((task.description ?? '').trim().isNotEmpty)
            _detail('Description', task.description!.trim()),
          pw.SizedBox(height: 20),
          if (rows.isEmpty)
            pw.Text('No non-zero quantity work items to report.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['S.No', ...columns],
              data: List.generate(
                  rows.length, (index) => ['${index + 1}', ...rows[index]]),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.6),
              cellPadding: const pw.EdgeInsets.all(5),
            ),
          pw.SizedBox(height: 28),
          pw.Text('Work Completed: Satisfactory / Unsatisfactory'),
          pw.SizedBox(height: 28),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Employee Signature: ____________________'),
              pw.Text('Authorized Signature: ____________________'),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'task-${task.id}-completion-report.pdf',
      onLayout: (_) => document.save(),
    );
  }

  static pw.Widget _detail(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: value),
          ]),
        ),
      );

  static String _date(DateTime? value) => value == null
      ? 'Not available'
      : DateFormat('dd/MM/yyyy').format(value.toLocal());
}
