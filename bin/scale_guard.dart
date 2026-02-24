import 'dart:io';

import 'package:scale_guard/scale_guard.dart';

void main(List<String> arguments) async {
  exit(await runCli(arguments));
}
