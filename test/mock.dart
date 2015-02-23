import 'dart:math' show Random;
import 'dart:async' show Future;
import 'dart:convert' show Encoding;

import 'package:duse/duse.dart';
import 'package:rsa/rsa.dart';
import 'package:restpoint/restpoint.dart';
import 'package:mock/mock.dart';
import 'package:http/http.dart';

@proxy
class KeyPairMock extends Mock implements KeyPair {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

@proxy
class UserInfoMock extends Mock implements UserEncryptionInformation {
  noSuchMethod(inv) => super.noSuchMethod(inv);
}

@proxy
class RandomMock extends Mock implements Random {
  noSuchMethod(inv) => super.noSuchMethod(inv);
}

@proxy
class ClientFactoryMock extends Mock with ClientFactory {
  noSuchMethod(inv) => super.noSuchMethod(inv);
  
  Function patchHandler;
  
  Future<Response> patch(url, {Map<String, String> headers, body,
    Encoding encoding}) =>
        patchHandler(url,
            headers: headers,
            body: body,
            encoding: encoding);
}

@proxy
class ClientMock extends Mock implements Client {
  Map<String, Function> handlers = {};
  
  Future<Response> post(url, {Map<String, String> headers, body,
    Encoding encoding}) =>
        handlers["post"](url,
            headers: headers,
            body: body,
            encoding: encoding);
  
  Future<Response> get(url, {Map<String, String> headers,
    Encoding encoding}) =>
        handlers["get"](url, 
            headers: headers,
            encoding: encoding);
  
  Future<Response> delete(url, {Map<String, String> headers}) =>
          handlers["delete"](url, 
              headers: headers,
              encoding: encoding);
                
  noSuchMethod(inv) => super.noSuchMethod(inv);
}



@proxy
class ResponseMock extends Mock implements Response {
  noSuchMethod(inv) => super.noSuchMethod(inv);
}