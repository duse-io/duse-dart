library duse_test;

import 'package:duse/src/duse_secret_encoder.dart';
import 'package:unittest/unittest.dart';

void main() => defineTests();

void defineTests() {
  group("SecretEncoder", () {
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
}
