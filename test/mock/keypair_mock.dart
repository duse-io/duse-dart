import 'package:rsa/rsa.dart';
import 'package:mock/mock.dart';

@proxy
class KeyPairMock extends Mock implements KeyPair {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}