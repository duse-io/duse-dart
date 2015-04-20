library duse.secret_encoder;

import 'dart:math' show min, Random;
import 'dart:convert' show UTF8;

import 'package:secret_sharing/secret_sharing.dart';
import 'package:crypto/crypto.dart' show CryptoUtils;
import 'package:rsa/rsa.dart';


class DuseSecret {
  final String title;
  final List<SecretFragment> fragments;
  
  DuseSecret(this.title, String secret, List<UserEncryptionInformation> users,
      KeyPair private, {int neededShares: 2, int split: 18})
      : fragments = generateFragments(secret, users, private, neededShares, split);
  
  DuseSecret.raw(this.title, this.fragments);
  
  Map<String, dynamic> toJson() => {
    "title": title,
    "parts": fragments.map((fragment) => fragment.toJson()).toList()
  };
  
  static List<SecretFragment> generateFragments(String secret,
      List<UserEncryptionInformation> users,
      KeyPair private, int neededShares, int split) {
    secret = utf8ToBase64(secret);
    var parts = divideString(secret, split);
    return parts.map((part) =>
        new SecretFragment(part, users, private, neededShares)).toList();
  }
  
  static List<String> divideString(String string, [int split = 18]) {
    var result = [];
    for (int i = 0; i < string.length; i += split) {
      result.add(string.substring(i, min(string.length, i + split)));
    }
    return result;
  }
  
  static String utf8ToBase64(String utf) {
    var utfBytes = UTF8.encode(utf);
    var res = CryptoUtils.bytesToBase64(utfBytes);
    return res;
  }
}

class UserEncryptionInformation {
  final int id;
  final KeyPair public;
  
  UserEncryptionInformation(this.id, this.public);
}

class SecretFragment {
  final List<SecretPart> parts;
  
  SecretFragment.raw(this.parts);
  
  List<Map<String, dynamic>> toJson() =>
      parts.map((part) => part.toJson()).toList();
  
  SecretFragment(String fragment,
      List<UserEncryptionInformation> users, KeyPair private,
      int neededShares)
      : parts = generateParts(fragment, users, private, neededShares);
  
  static List<SecretPart> generateParts(String fragment,
      List<UserEncryptionInformation> users,
      KeyPair private, int neededShares, {Random random}) {
    var encoder = new StringShareEncoder(users.length, neededShares,
        new ASCIICharset(), random: random);
    var shares = encoder.convert(fragment);
    var parts = [];
    for (int i = 0; i < users.length; i++) {
      parts.add(new SecretPart(shares[i].toString(), users[i], private));
    }
    return parts;
  }
}

class SecretPart {
  final int userId;
  final String share;
  final String signature;
  
  SecretPart.raw(this.userId, this.share, this.signature);
  
  factory SecretPart(String share, UserEncryptionInformation user,
      KeyPair private) {
    var encryptedShare = user.public.encrypt(share);
    var signature = private.sign(encryptedShare);
    return new SecretPart.raw(user.id, encryptedShare, signature);
  }
  
  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "content": share,
    "signature": signature
  };
}