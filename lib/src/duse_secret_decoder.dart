library duse.secret_decoder;

import 'dart:convert' show UTF8;

import 'package:crypto/crypto.dart' show CryptoUtils;
import 'package:rsa/rsa.dart';
import 'package:secret_sharing/secret_sharing.dart';

class EncodedSecret {
  final List<DuseFragment> fragments;
  
  EncodedSecret(this.fragments);
  
  EncodedSecret.raw(List<List<String>> shares)
      : fragments = shares.map((share) => new DuseFragment(share)).toList();
  
  String decode(KeyPair pair) {
    return fragments.map((fragment) => fragment.decode(pair))
                    .fold("", (result, current) => result + current);
  }
}

class DuseFragment {
  final List<String> shares;
  
  DuseFragment(this.shares);
  
  String decode(KeyPair pair) {
    var stringShares = shares.map((cipher) => pair.decrypt(cipher))
                             .map((share) => new StringShare.parse(share))
                             .toList();
    var result = new StringShareDecoder().convert(stringShares);
    return base64toUtf8(result);
  }
  
  static String base64toUtf8(String base64) {
    var utfBytes = CryptoUtils.base64StringToBytes(base64);
    return UTF8.decode(utfBytes);
  }
}