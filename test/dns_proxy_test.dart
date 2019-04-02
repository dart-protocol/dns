// Copyright 2019 Gohilla.com team.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:dns/dns.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

import '../bin/dns-proxy.dart' as proxy;

void main() {
  test("DNS proxy executable", () async {
    // Start server
    const port = 4242;
    proxy.main(["serve", "--silent", "--host=127.0.0.1", "--port=${port.toString()}"]);

    // Wait 100ms
    await Future.delayed(const Duration(milliseconds: 100));

    // Query "google.com"
    final client = UdpDnsClient(
      remoteAddress: InternetAddress.loopbackIPv4,
      remotePort: port,
    );
    final result = await client.lookup("google.com");

    // Expect at least 1 IP address
    expect(result, hasLength(greaterThan(0)));
  });
}
