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

import 'package:universal_io/io.dart';

/// Provides access to Mac OS X network settings.
class MacNetworkSettings {
  /// Returns DNS servers.
  Future<List<InternetAddress>> getDnsServers() async {
    final result = await _networkSetup(["-getdnsservers", "Wi-Fi"]);
    if (result.contains("There aren't any")) {
      return [];
    }
    return result
        .split("\n")
        .map((line) {
          line = line.trim();
          if (line.isEmpty) {
            return null;
          }
          try {
            return InternetAddress(line);
          } catch (e) {
            return null;
          }
        })
        .where((item) => item != null)
        .toList();
  }

  /// Sets DNS servers.
  Future setDnsServers(List<InternetAddress> addresses) async {
    final args = ["-setdnsservers", "Wi-Fi"];
    if (addresses.isEmpty) {
      args.add("Empty");
    } else {
      args.addAll(addresses.map((item) => item.address));
    }
    return _networkSetup(args);
  }

  Future<String> _networkSetup(List<String> args) async {
    if (Platform.isMacOS == false) {
      throw StateError("The current operating system is not Mac OS X");
    }
    const executable = "networksetup";
    final process = await Process.run(
      executable,
      args,
      stdoutEncoding: systemEncoding,
    );
    final stderr = process.stderr as String;
    if (stderr.isNotEmpty) {
      throw StateError("Error: $stderr");
    }
    return process.stdout as String;
  }
}
