import 'package:intl/intl.dart';

final _money = NumberFormat.decimalPattern('vi_VN');

/// `8500000` → `8.500.000đ`, như IKiot-FE.
String formatMoney(num value) => '${_money.format(value.round())}đ';
