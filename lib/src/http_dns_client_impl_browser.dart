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

// This file SHOULD NOT be exported!

import 'dart:async';
import 'dart:convert';
import 'dart:html';

Future<Object> fetchJson(String url) async {
  final body = await HttpRequest.getString(url);
  return const JsonDecoder().convert(body);
}
