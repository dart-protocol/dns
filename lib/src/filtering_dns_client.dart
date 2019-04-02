import 'dart:async';

import 'package:ip/ip.dart';
import 'package:universal_io/io.dart';

import 'dns_client.dart';
import 'dns_packet.dart';

typedef void Callback<T>(T argument);

/// A DNS client that can log or modify questions and answers.
class FilteringDnsClient extends DelegatingDnsClient {
  final Callback<DnsPacket> beforeOperation;
  final Callback<DnsPacket> afterOperation;

  FilteringDnsClient(DnsClient client, {this.beforeOperation, this.afterOperation})
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
    if (result!=null && afterOperation != null) {
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
