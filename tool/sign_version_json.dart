// Signs version.json with the release private key before publishing an
// update (audit TD-61 / Update-Signierung). The app refuses an unsigned or
// wrongly signed version.json (see lib/services/version_signature.dart).
//
// Usage:
//   dart run tool/sign_version_json.dart --input version.json --output version.json \
//     --private-key "<base64 private key>"
// or, to avoid the key appearing in shell history:
//   set NEXUS_RELEASE_PRIVATE_KEY=<base64 private key>   (PowerShell: $env:...)
//   dart run tool/sign_version_json.dart --input version.json --output version.json
//
// The private key is never committed; find it in the release key sicherung
// (see docs/current/TECH_DEBT.md, R-1 / TD-61).
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  String? input;
  String? output;
  String? privateKeyB64;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--input':
        input = args[++i];
      case '--output':
        output = args[++i];
      case '--private-key':
        privateKeyB64 = args[++i];
    }
  }
  privateKeyB64 ??= Platform.environment['NEXUS_RELEASE_PRIVATE_KEY'];
  input ??= 'version.json';
  output ??= input;

  if (privateKeyB64 == null || privateKeyB64.isEmpty) {
    stderr.writeln('Fehlt: --private-key oder NEXUS_RELEASE_PRIVATE_KEY');
    exitCode = 1;
    return;
  }

  final file = File(input);
  if (!file.existsSync()) {
    stderr.writeln('Datei nicht gefunden: $input');
    exitCode = 1;
    return;
  }

  final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  data.remove('sig');

  final keyPair = await Ed25519().newKeyPairFromSeed(base64Decode(privateKeyB64));
  final sortedKeys = data.keys.toList()..sort();
  final canonical = utf8.encode(jsonEncode({for (final k in sortedKeys) k: data[k]}));
  final signature = await Ed25519().sign(canonical, keyPair: keyPair);

  data['sig'] = base64Encode(signature.bytes);

  final publicKeyHex = (await keyPair.extractPublicKey())
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  stderr.writeln('Signiert mit öffentlichem Schlüssel: $publicKeyHex');
  stderr.writeln(
      '(muss zu VersionSignature.releasePublicKeyHex im Code passen)');

  const encoder = JsonEncoder.withIndent('  ');
  await File(output).writeAsString('${encoder.convert(data)}\n');
  stderr.writeln('Geschrieben: $output');
}
