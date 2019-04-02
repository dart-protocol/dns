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
import 'package:meta/meta.dart';

import 'dns_client.dart';
import 'dns_packet.dart';
import 'http_dns_client_impl_vm.dart'
    if (dart.library.html) 'http_dns_client_impl_browser/dns_packet_test.dart';
import 'udp_dns_client.dart';
import 'package:universal_io/io.dart';

/// DNS client that uses DNS-over-HTTPS protocol supported by Google and
/// Cloudflare.
///
/// See:
///   * [Google DNS-over-HTTPS documentation](https://developers.google.com/speed/public-dns/docs/dns-over-https)
///   * [Cloudflare DNS-over-HTTPS documentation](https://developers.cloudflare.com/1.1.1.1/dns-over-https/json-format/)
///   * [IETF working group](https://datatracker.ietf.org/wg/doh/about/)
///
class HttpDnsClient extends PacketBasedDnsClient {
  /// URL of the service (without query).
  final String url;
  final String _urlHost;

  /// Resolves host of the the URL.
  final DnsClient urlClient;

  /// Whether to hide client IP address from the authoritative server.
  final bool maximalPrivacy;

  /// Default timeout for operations.
  final Duration timeout;

  /// Constructs a DNS-over-HTTPS client.
  ///
  /// If `maximalPrivacy` is true, then DNS client should do its best to hide
  /// IP address of the client from the authoritative DNS server.
  ///
  /// If `urlClient` is non-null, it will be used to resolve IP of the
  /// host of the URL. Otherwise DNS-over-UDP server at 8.8.8.8 will be used.
  HttpDnsClient(this.url,
      {this.timeout, this.maximalPrivacy = false, this.urlClient})
      : this._urlHost = Uri.parse(url).host {
    if (url.contains("?")) {
      throw ArgumentError.value(url, "url");
    }
  }

  /// Constructs a DNS-over-HTTPS client that uses Google's free servers.
  ///
  /// If `maximalPrivacy` is true, we will ask Google to hide our IP from the
  /// authoritative DNS server. Default is false, which enables the DNS server
  /// to return us physically close IPs, resulting in potentially much better
  /// throughput/latency.
  ///
  /// If `urlClient` is non-null, it will be used to resolve 'dns.google.com'.
  /// Otherwise DNS-over-UDP server at 8.8.8.8 will be used.
  ///
  /// See [documentation at developers.google.com](https://developers.google.com/speed/public-dns/docs/dns-over-https).
  HttpDnsClient.google({
    Duration timeout,
    maximalPrivacy = false,
    DnsClient urlClient,
  }) : this(
          "https://dns.google.com/resolve",
          timeout: timeout,
          maximalPrivacy: maximalPrivacy,
          urlClient: urlClient,
        );

  @override
  Future<DnsPacket> lookupPacket(String host,
      {InternetAddressType type = InternetAddressType.any}) async {
    //  Are we are resolving host of the DNS-over-HTTPS service?
    if (host == _urlHost) {
      final selfClient = this.urlClient ?? new UdpDnsClient.google();
      return selfClient.lookupPacket(host, type: type);
    }

    // Build URL
    var url = "${this.url}?name=${Uri.encodeQueryComponent(host)}";

    // Add: IPv4 or IPv6?
    if (type == null) {
      throw new ArgumentError.notNull("type");
    } else if (type == InternetAddressType.any ||
        type == InternetAddressType.IPv4) {
      url += "&type=A";
    } else {
      url += "&type=AAAA";
    }

    // Hide my IP?
    if (maximalPrivacy) {
      url += "&edns_client_subnet=0.0.0.0/0";
    }

    // Fetch.
    // We have two implementations, one for browser and one for VM.
    final json = await fetchJson(url);

    // Decode
    return decodeDnsPacket(json);
  }

  /// Converts JSON object to [DnsPacket].
  @visibleForTesting
  DnsPacket decodeDnsPacket(Object json) {
    if (json is Map) {
      final result = DnsPacket.withResponse();
      for (var key in json.keys) {
        final value = json[key];

        switch (key) {
          case "Status":
            result.responseCode = (value as num).toInt();
            break;

          case "AA":
            result.isAuthorativeAnswer = value as bool;
            break;

          case "ID":
            result.id = (value as num).toInt();
            break;

          case "QR":
            result.isResponse = value as bool;
            break;

          case "RA":
            result.isRecursionAvailable = value as bool;
            break;

          case "RD":
            result.isRecursionDesired = value as bool;
            break;

          case "TC":
            result.isTruncated = value as bool;
            break;

          case "Question":
            final questions = <DnsQuestion>[];
            result.questions = questions;
            if (value is List) {
              for (var item in value) {
                questions.add(decodeDnsQuestion(item));
              }
            }
            break;

          case "Answer":
            final answers = <DnsResourceRecord>[];
            result.answers = answers;
            if (value is List) {
              for (var item in value) {
                answers.add(decodeDnsResourceRecord(item));
              }
            }
            break;

          case "Additional":
            final additionalRecords = <DnsResourceRecord>[];
            result.additionalRecords = additionalRecords;
            if (value is List) {
              for (var item in value) {
                additionalRecords.add(decodeDnsResourceRecord(item));
              }
            }
            break;
        }
      }
      return result;
    } else {
      throw ArgumentError.value(json);
    }
  }

  /// Converts JSON object to [DnsQuestion].
  @visibleForTesting
  DnsQuestion decodeDnsQuestion(Object json) {
    if (json is Map) {
      final result = DnsQuestion();
      for (var key in json.keys) {
        final value = json[key];
        switch (key) {
          case "name":
            result.name = _trimDotSuffix(value as String);
            break;
        }
      }
      return result;
    } else {
      throw ArgumentError.value(json);
    }
  }

  /// Converts JSON object to [DnsResourceRecord].
  @visibleForTesting
  DnsResourceRecord decodeDnsResourceRecord(Object json) {
    if (json is Map) {
      final result = DnsResourceRecord();
      for (var key in json.keys) {
        final value = json[key];
        switch (key) {
          case "name":
            result.name = _trimDotSuffix(value as String);
            break;

          case "type":
            result.type = (value as num).toInt();
            break;

          case "TTL":
            result.ttl = (value as num).toInt();
            break;

          case "data":
            result.data = IpAddress.parse(value).toImmutableBytes();
            break;
        }
      }
      return result;
    } else {
      throw ArgumentError.value(json);
    }
  }

  static String _trimDotSuffix(String s) {
    if (s.endsWith(".")) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }
}
