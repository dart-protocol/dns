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
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:dns/dns.dart';
import 'package:dns/src/dns_settings.dart';
import 'package:ip/ip.dart';
import 'package:universal_io/io.dart';

List<String> _mainArgs = [];

/// You can run this function with:
/// ```
/// pub run bin/dns_proxy.dart
/// ```
void main(List<String> args) async {
  _mainArgs = args;
  final runner = CommandRunner("dns_proxy", "DNS proxy");
  runner.addCommand(ServeCommand());
  await runner.run(args);
}

class ServeCommand extends Command {
  @override
  String get name => "serve";

  @override
  String get description => "Starts DNS proxy";

  ServeCommand() {
    argParser.addOption(
      "https",
      help: "DNS-over-HTTPS service URL",
    );
    argParser.addOption(
      "host",
      defaultsTo: "127.0.0.1",
      help: "Local IP interface",
    );
    argParser.addOption(
      "port",
      defaultsTo: "53",
      help: "Local UDP port",
    );
    argParser.addFlag(
      "silent",
      defaultsTo: false,
      help: "Disable debug messages",
    );
    if (Platform.isMacOS) {
      argParser.addFlag("configure", defaultsTo: false);
    }
  }

  @override
  void run() async {
    final host = InternetAddress(argResults!["host"]);
    final port = int.parse(argResults!["port"]);
    final dnsOverHttpsUrl = argResults!["https"];
    final isSilent = argResults!["silent"];

    // Define client
    var client = HttpDnsClient.google(maximalPrivacy: true);
    if (dnsOverHttpsUrl != null) {
      client = HttpDnsClient(dnsOverHttpsUrl, maximalPrivacy: true);
    }

    // Add logging
    final filteringClient =
        FilteringDnsClient(client, beforeOperation: (DnsPacket packet) {
      if (!isSilent) {
        for (var question in packet.questions) {
          final typeName = DnsQuestion.stringFromType(question.type);
          print("Lookup: ${question.name} ($typeName)");
        }
      }
    }, afterOperation: (packet) {
      if (!isSilent) {
        var first = true;
        for (var answer in packet.answers) {
          final typeName = DnsResourceRecord.stringFromType(answer.type);
          final ip = IpAddress.fromBytes(answer.data);
          if (first) {
            first = false;
            print("Answer: ${answer.name} ($typeName)");
          }
          print("  --> $ip");
        }
      }
    });

    // By default, we are not configuring systems settings for you

    // In OS X, we support changing system DNS server (temporarily)
    if (Platform.isMacOS) {
      final isConfigureFlag = argResults!["configure"] as bool;
      if (isConfigureFlag) {
        // Port must the default port
        if (!isSilent && port != DnsServer.defaultPort) {
          print("'--configure' requires that port is ${DnsServer.defaultPort}");
        }

        // We need root permissions
        if (_whoami() != "root") {
          final future = _startSudoProcess(host, port);

          // Check every 100ms whether the server is already running
          Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (_processOut.toString().contains("\nResolving with:")) {
              timer.cancel();
              _configureMacOS(host);
            }
          });
          await future;
          return;
        }
      }
    }

    // Start server
    if (!isSilent) {
      print("");
      print("Starting local DNS proxy at: 127.0.0.1:$port");
      print("Resolving with: ${client.url}");
      print("");
    }
    await DnsServer.bind(filteringClient, address: host, port: port);
  }

  Future<void> _startSudoProcess(InternetAddress address, int port) async {
    final executable = "sudo";
    final executableArgs = [Platform.executable]
      ..addAll(Platform.executableArguments)
      ..add(Platform.script.path)
      ..addAll(_mainArgs);
    final i = executableArgs.lastIndexOf("--configure");
    if (i < 0) {
      final commandString = "$executable ${executableArgs.join(' ')}";
      throw StateError("Failed to remove '--configure' from: $commandString");
    }
    executableArgs.removeAt(i);
    print("""
--------------------------------------------------------------------------------
Setting up DNS server at port $port requires administrator permissions.
--------------------------------------------------------------------------------

Therefore, we run:
  $executable ${executableArgs.join(' ')}

Command 'sudo' usually asks your password.
--------------------------------------------------------------------------------
""");
    final process = await Process.start(executable, executableArgs);
    _pipeToTerminal(process);
  }

  final StringBuffer _processOut = StringBuffer();

  void _pipeToTerminal(Process process) {
    stdin.pipe(process.stdin);
    process.stdout.listen((data) {
      _processOut.write(utf8.decode(data));
      stdout.add(data);
    });
    process.stderr.pipe(stderr);
  }

  static void _configureMacOS(InternetAddress address) async {
    final client = MacNetworkSettings();
    final oldServers = await client.getDnsServers();
    final oldServerString = oldServers.map((item) => item!.address).join(', ');
    print("");
    print("Old DNS servers: [$oldServerString]");
    var isRestored = false;
    final onSignal = (ProcessSignal signal) async {
      if (!isRestored) {
        isRestored = true;
        print("");
        print("Restoring old DNS servers: [$oldServerString]");
        print("");
        await client.setDnsServers(oldServers.cast());
      }
      exit(0);
    };
    ProcessSignal.sigint.watch().listen(onSignal);
    print("New DNS servers: [${address.address}]");
    print("");
    await client.setDnsServers([address]);
  }
}

String _whoami() {
  final result = Process.runSync("whoami", []);
  return (result.stdout as String).trim();
}
