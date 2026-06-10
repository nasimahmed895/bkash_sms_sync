import 'package:logger/logger.dart';

/// Single shared logger instance.
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 6,
    colors: false,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
);
