library duse.test.secret_decoder;

import 'mock.dart';

import 'package:secret_sharing/secret_sharing.dart';
import 'package:duse/src/duse_secret_decoder.dart';
import 'package:unittest/unittest.dart';
import 'package:mock/mock.dart';

void defineTests() {
  group("SecretDecoder", () {
    group("DuseFragment", () {
      test("decode", () {
        var random = new RandomMock()
          ..when(callsTo("nextInt", anything)).alwaysReturn(0);
        var encoder = new StringShareEncoder(2, 2, new ASCIICharset(),
            random: random);
        var shares = encoder.convert("test").map((share) => share.toString())
                                            .toList();
        var private = new KeyPairMock()
          ..when(callsTo("decrypt", "1-e9979f4")).thenReturn("1-e9979f4")
          ..when(callsTo("decrypt", "2-e9979f4")).thenReturn("2-e9979f4");
        var fragment = new DuseFragment(shares);
        
        expect(fragment.decode(private), equals("test"));
      });
    });
    
    group("EncodedSecret", () {
      test("decode", () {
        var random = new RandomMock()
          ..when(callsTo("nextInt", anything)).alwaysReturn(0);
        var encoder = new StringShareEncoder(2, 2, new ASCIICharset(),
            random: random);
        var shares = encoder.convert("test").map((share) => share.toString())
                                            .toList();
        var private = new KeyPairMock()
          ..when(callsTo("decrypt", "1-e9979f4")).alwaysReturn("1-e9979f4")
          ..when(callsTo("decrypt", "2-e9979f4")).alwaysReturn("2-e9979f4");
        var fragment = new DuseFragment(shares);
        var fragments = new List.filled(4, fragment);
        var secret = new EncodedSecret(fragments);
        
        expect(secret.decode(private), equals("test" * 4));
      });
    });
  });
}