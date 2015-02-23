library duse.test.secret_encoder;

import 'mock.dart';

import 'package:duse/src/duse_secret_encoder.dart';
import 'package:unittest/unittest.dart';
import 'package:mock/mock.dart';

void defineTests() {
  group("SecretEncoder", () {
    group("DuseSecret", (){
      group("divideString", () {
        test("exact size", () {
          var test = "123456789";
          expect(DuseSecret.divideString(test, 9), equals(["123456789"]));
        });
        
        test("regular divide", () {
          var test = "This is a long sentence, it should be split into some parts";
          
          expect(DuseSecret.divideString(test), equals([
              "This is a long sen",
              "tence, it should b",
              "e split into some ",
              "parts"
          ]));
        });
        
        test("generateFragments", () {
          var private = new KeyPairMock()
            ..when(callsTo("sign", anything))
             .thenReturn("SIGNATURE1")
             .thenReturn("SIGNATURE2");
          var random = new RandomMock()
            ..when(callsTo("nextInt")).alwaysReturn(0);
          var public = new KeyPairMock()
            ..when(callsTo("encrypt", anything))
             .thenReturn("ENCRYPTED1")
             .thenReturn("ENCRYPTED2");
          var user = new UserInfoMock()
            ..when(callsTo("get public")).alwaysReturn(public)
            ..when(callsTo("get id")).thenReturn(1)
                                     .thenReturn(2);  
          var users = new List.filled(2, user);
          
          var fragments =
              DuseSecret.generateFragments("my secret", users, private, 2, 10);
          var parts = fragments.single.parts;
          
          expect(parts.first.share, equals("ENCRYPTED1"));
          expect(parts.first.signature, equals("SIGNATURE1"));
          expect(parts.last.share, equals("ENCRYPTED2"));
          expect(parts.last.signature, equals("SIGNATURE2"));
        });
        
        test("toJson", () {
          var part = new SecretPart.raw(1, "share", "signature");
          var fragment = new SecretFragment.raw([part]);
          var secret = new DuseSecret.raw("title", [fragment]);
          
          expect(secret.toJson(),
              equals({"title": "title", "parts": [fragment.toJson()]}));
        });
      });
    });
    
    group("SecretPart", () {
      test("constructor", () {
        var publicMock = new KeyPairMock();
        publicMock.when(callsTo("encrypt", "test")).thenReturn("ENCRYPTED");
        var privateMock = new KeyPairMock();
        privateMock.when(callsTo("sign", "ENCRYPTED")).thenReturn("SIGNATURE");
        var userInfo = new UserEncryptionInformation(1, publicMock);
        
        var part = new SecretPart("test", userInfo, privateMock);
        expect(part.share, equals("ENCRYPTED"));
        expect(part.signature, equals("SIGNATURE"));
        expect(part.userId, equals(1));
        publicMock.getLogs(callsTo("encrypt", "test")).verify(happenedOnce);
        privateMock.getLogs(callsTo("sign", "ENCRYPTED")).verify(happenedOnce);
      });
      
      test("toJson", () {
        var part = new SecretPart.raw(1, "test", "signature");
        expect(part.toJson(), equals({
          "user_id": 1,
          "content": "test",
          "signature": "signature"
        }));
      });
    });
    
    group("SecretFragment", () {
      test("generateParts", () {
        var private = new KeyPairMock()
          ..when(callsTo("sign", anything))
           .thenReturn("SIGNATURE1")
           .thenReturn("SIGNATURE2");
        var random = new RandomMock()
          ..when(callsTo("nextInt")).alwaysReturn(0);
        var public = new KeyPairMock()
          ..when(callsTo("encrypt", anything))
           .thenReturn("ENCRYPTED1")
           .thenReturn("ENCRYPTED2");
        var user = new UserInfoMock()
          ..when(callsTo("get public")).alwaysReturn(public)
          ..when(callsTo("get id")).thenReturn(1)
                                   .thenReturn(2);  
        var users = new List.filled(2, user);
        
        var parts = SecretFragment.generateParts("fragment", users, private,
            2, random: random);
        
        expect(parts.first.share, equals("ENCRYPTED1"));
        expect(parts.first.signature, equals("SIGNATURE1"));
        expect(parts.last.share, equals("ENCRYPTED2"));
        expect(parts.last.signature, equals("SIGNATURE2"));
      });
      
      test("toJson", () {
        var part = new SecretPart.raw(1, "test", "signature");
        var fragment = new SecretFragment.raw([part]);
        
        expect(fragment.toJson(), equals(
            [part.toJson()]));
      });
    });
  });
}
