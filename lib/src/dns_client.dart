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

import 'dns_packet.dart';
import 'http_dns_client.dart';
import 'udp_dns_client.dart';

/// Abstract superclass of DNS clients.
///
/// Commonly used implementations:
///   * [UdpDnsClient]
///   * [HttpDnsClient]
abstract class DnsClient {
  static const Duration defaultTimeout = Duration(seconds: 5);

  /// Queries IP address of the host and returns the list of all answers.
  Future<List<IpAddress>> lookup(String name,
      {InternetAddressType type = InternetAddressType.any});

  /// Queries IP address of the host and returns the full DNS packet.
  Future<DnsPacket> lookupPacket(String name,
      {InternetAddressType type = InternetAddressType.any}) async {
    final list = await lookup(name);
    final result = DnsPacket.withResponse();
    result.answers = list.map((ipAddress) {
      final type = ipAddress is Ip4Address
          ? DnsResourceRecord.typeIp4
          : DnsResourceRecord.typeIp6;
      return DnsResourceRecord.withAnswer(
          name: name, type: type, data: ipAddress.toImmutableBytes());
    }).toList();
    return result;
  }

  Future<DnsPacket?> handlePacket(DnsPacket packet, {Duration? timeout}) async {
    if (packet.questions.isEmpty) {
      return null;
    }
    if (packet.questions.length == 1) {
      final question = packet.questions.single;
      switch (question.type) {
        case DnsQuestion.typeIp4:
          return lookupPacket(packet.questions.single.name,
              type: InternetAddressType.IPv4);
        case DnsQuestion.typeIp6:
          return lookupPacket(packet.questions.single.name,
              type: InternetAddressType.IPv4);
        default:
          return null;
      }
    }
    final result = DnsPacket.withResponse();
    result.id = packet.id;
    result.answers = <DnsResourceRecord>[];
    final futures = <Future>[];
    for (var question in packet.questions) {
      var type = InternetAddressType.any;
      switch (question.type) {
        case DnsQuestion.typeIp4:
          type = InternetAddressType.IPv4;
          break;
        case DnsQuestion.typeIp6:
          type = InternetAddressType.IPv6;
          break;
      }
      futures.add(lookupPacket(question.name, type: type).then((packet) {
        result.answers.addAll(packet.answers);
      }));
    }
    await Future.wait(futures).timeout(timeout ?? defaultTimeout);
    return result;
  }
}

/// Uses system DNS lookup method.
class SystemDnsClient extends DnsClient {
  @override
  Future<List<IpAddress>> lookup(String host,
      {InternetAddressType type = InternetAddressType.any}) async {
    final addresses = await InternetAddress.lookup(host, type: type);
    return addresses
        .map((item) => IpAddress.fromBytes(item.rawAddress))
        .toList();
  }
}

/// Superclass of packet-based clients.
///
/// See:
///   * [UdpDnsClient]
///   * [HttpDnsClient]
abstract class PacketBasedDnsClient extends DnsClient {
  Future<DnsPacket> lookupPacket(String host,
      {InternetAddressType type = InternetAddressType.any});

  @override
  Future<List<IpAddress>> lookup(String host,
      {InternetAddressType type = InternetAddressType.any}) async {
    final packet = await lookupPacket(host, type: type);
    final result = <IpAddress>[];
    for (var answer in packet.answers) {
      if (answer.name == host) {
        final ipAddress = IpAddress.fromBytes(answer.data);
        result.add(ipAddress);
      }
    }
    return result;
  }
}

/// An exception that indicates failure by [DnsClient].
class DnsClientException implements Exception {
  final String message;

  DnsClientException(this.message);

  @override
  String toString() => message;
}

/// A DNS client that delegates operations to another client.
class DelegatingDnsClient implements DnsClient {
  final DnsClient client;

  DelegatingDnsClient(this.client);

  @override
  Future<List<IpAddress>> lookup(String host,
      {InternetAddressType type = InternetAddressType.any}) {
    return client.lookup(host, type: type);
  }

  @override
  Future<DnsPacket?> handlePacket(DnsPacket packet, {Duration? timeout}) {
    return client.handlePacket(packet, timeout: timeout);
  }

  @override
  Future<DnsPacket> lookupPacket(String host,
      {InternetAddressType type = InternetAddressType.any}) {
    return client.lookupPacket(host, type: type);
  }
}
