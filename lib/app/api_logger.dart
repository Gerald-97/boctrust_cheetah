import 'package:logger/logger.dart';

final Logger apiLogger = Logger(
  filter: ProductionFilter(),
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 140,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
