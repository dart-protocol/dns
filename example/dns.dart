import 'package:dns/dns.dart';
import 'dart:async';

Future<void> main(List<String> args) async {
  for (var arg in args) {
    final client = HttpDnsClient.google();
    final result = await client.lookup("google.com");
    print("$arg --> ${result.join(' | ')}");
  }
}
