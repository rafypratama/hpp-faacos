import 'package:intl/intl.dart';

class AppFormatter {
  /**
   * Format numbers to Indonesian Rupiah (Rp).
   */
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /**
   * Format decimals, stripping unnecessary trailing zeros (e.g. 15.0000 -> 15).
   */
  static String formatQuantity(double quantity, String unit) {
    final formatter = NumberFormat("#,##0.####", "id_ID");
    final formattedNum = formatter.format(quantity);
    return '$formattedNum $unit';
  }

  /**
   * Format dates beautifully (e.g. 19 May 2026, 07:27).
   */
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
  }
}
