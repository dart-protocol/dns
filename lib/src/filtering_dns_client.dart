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

import 'package:ip/ip.dart';
import 'package:universal_io/io.dart';

import 'dns_client.dart';
import 'dns_packet.dart';

typedef Callback<T> = void Function(T argument);

/// A DNS client that can log or modify questions and answers.
class FilteringDnsClient extends DelegatingDnsClient {
  final Callback<DnsPacket> beforeOperation;
  final Callback<DnsPacket> afterOperation;

  FilteringDnsClient(DnsClient client,
      {this.beforeOperation, this.afterOperation})
      : super(client);

  @override
  Future<List<IpAddress>> lookup(String host,
      {InternetAddressType type = InternetAddressType.any}) async {
    if (beforeOperation != null) {
      final packet = DnsPacket();
      packet.questions.add(DnsQuestion(host: host));
      beforeOperation(packet);
    }
    final result = await super.lookup(host);
    if (afterOperation != null) {
      final packet = DnsPacket();
      for (var ip in result) {
        final answer = DnsResourceRecord();
        answer.name = host;
        if (ip.isIpv4) {
          answer.type = DnsResourceRecord.typeIp4;
        } else {
          answer.type = DnsResourceRecord.typeIp6;
        }
        answer.data = ip.toImmutableBytes();
        packet.answers.add(answer);
      }
      afterOperation(packet);
    }
    return result;
  }

  @override
  Future<DnsPacket> handlePacket(DnsPacket packet, {Duration timeout}) async {
    if (beforeOperation != null) {
      beforeOperation(packet);
    }
    final result = await super.handlePacket(packet, timeout: timeout);
    if (result != null && afterOperation != null) {
      afterOperation(result);
    }
    return result;
  }

  @override
  Future<DnsPacket> lookupPacket(String host,
      {InternetAddressType type = InternetAddressType.any}) async {
    if (beforeOperation != null) {
      final packet = DnsPacket();
      packet.questions.add(DnsQuestion(host: host));
      beforeOperation(packet);
    }
    final result = await super.lookupPacket(host, type: type);
    if (afterOperation != null) {
      afterOperation(result);
    }
    return result;
  }
}
