library duse.secret_decoder;

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
    return new StringShareDecoder().convert(stringShares);
  }
}