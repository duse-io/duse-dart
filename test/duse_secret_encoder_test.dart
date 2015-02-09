library duse_test;

import 'mock/keypair_mock.dart';

import 'package:duse/src/duse_secret_encoder.dart';
import 'package:unittest/unittest.dart';
import 'package:mock/mock.dart';

void main() => defineTests();

void defineTests() {
  group("SecretEncoder", () {
    group("DuseSecret", (){
      group("divideSecret", () {
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
  });
}
