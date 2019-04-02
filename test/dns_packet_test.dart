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

import 'package:dns/dns.dart';
import 'package:ip/foundation.dart';
import 'package:raw/raw.dart';
import 'package:raw/test_helpers.dart';
import 'package:test/test.dart';

void main() {
  group("DnsPacket", () {
    group("default", () {
      final example = DnsPacket();

      test("encode, decode", () {
        final reader = RawReader.withBytes(example.toImmutableBytes());
        final decoded = DnsPacket();
        decoded.decodeSelf(reader);
        expect(decoded, selfEncoderEquals(example));
        expect(reader.availableLengthInBytes, 0);
      });
    });

    group("example #1", () {
      List<int> exampleBytes;
      DnsPacket example;

      setUp(() {
        exampleBytes = const DebugHexDecoder().convert("""
0x0000: db42 8180  0001 0001  0000 0000  0377 7777
0x0010: 0765 7861  6d70 6c65  0363 6f6d  0000 0100
0x0020: 01c0 0c00  0100 0100  0002 5800  049b 2111
0x0030: 44
""");

        final question = DnsQuestion();
        question.nameParts.addAll(["www", "example", "com"]);
        question.type = 1;
        question.classy = 1;

        final answer = DnsResourceRecord();
        answer.nameParts = const ["www", "example", "com"];
        answer.type = 1;
        answer.classy = 1;
        answer.ttl = 600;
        answer.data = const <int>[0x9b, 0x21, 0x11, 0x44];

        example = DnsPacket();
        example.id = 0xdb42;
        example.isResponse = true;
        example.op = 0;
        example.isTruncated = false;
        example.isRecursionDesired = true;
        example.isRecursionAvailable = true;
        example.responseCode = 0;
        example.questions = [question];
        example.answers = [answer];
      });

      test("decoded properties", () {
        final decoded = DnsPacket();
        decoded.decodeSelf(RawReader.withBytes(exampleBytes));

        //
        // First bytes
        //

        expect(decoded.isResponse, equals(true));
        expect(decoded.op, equals(0));
        expect(decoded.isTruncated, equals(false));
        expect(decoded.isRecursionDesired, equals(true));
        expect(decoded.isRecursionAvailable, equals(true));
        expect(decoded.responseCode, equals(0));

        //
        // Questions
        //

        expect(decoded.questions, hasLength(1));

        final decodedQuestion = decoded.questions.single;
        final expectedQuestion = example.questions.single;

        expect(decodedQuestion.nameParts, equals(expectedQuestion.nameParts));
        expect(decodedQuestion.type, equals(expectedQuestion.type));
        expect(decodedQuestion.classy, equals(expectedQuestion.classy));
        expect(decoded.questions, orderedEquals([expectedQuestion]));

        //
        // Answers
        //

        expect(decoded.answers, hasLength(1));

        final decodedAnswer = decoded.answers.single;
        final expectedAnswer = example.answers.single;

        expect(decodedAnswer.nameParts, equals(expectedAnswer.nameParts));
        expect(decodedAnswer.type, equals(expectedAnswer.type));
        expect(decodedAnswer.classy, equals(expectedAnswer.classy));
        expect(decodedAnswer.ttl, equals(expectedAnswer.ttl));
        expect(decodedAnswer.data, equals(expectedAnswer.data));
        expect(decoded.answers, orderedEquals([expectedAnswer]));

        //
        // Other
        //

        expect(decoded.authorities, hasLength(0));
        expect(decoded.additionalRecords, hasLength(0));
      });

      test("encode, decode, encode", () {
        // encode
        final writer = RawWriter.withCapacity(500);
        example.encodeSelf(writer);
        final encoded = writer.toUint8ListView();
        expect(encoded, byteListEquals(exampleBytes));
        final encodedReader = RawReader.withBytes(encoded);

        // encode -> decode
        final decoded = DnsPacket();
        decoded.decodeSelf(encodedReader);

        // encode -> decode -> encode
        // (the next two lines should both encode)
        expect(decoded.toImmutableBytes(), byteListEquals(exampleBytes));
        expect(decoded, selfEncoderEquals(example));
        expect(encodedReader.availableLengthInBytes, 0);
      });

      test("decode", () {
        final reader = RawReader.withBytes(exampleBytes);
        final decoded = DnsPacket();
        decoded.decodeSelf(reader);
        expect(decoded, selfEncoderEquals(example));
        expect(reader.availableLengthInBytes, 0);
      });
    });
  });
}
