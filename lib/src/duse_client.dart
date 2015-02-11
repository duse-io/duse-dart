library duse.client;

import 'dart:async' show Future;
import 'dart:convert' show JSON;

import 'duse_secret_decoder.dart' as decoder;
import 'duse_secret_encoder.dart' as encoder;

import 'package:restpoint/restpoint.dart';
import 'package:rsa/rsa.dart';

class DuseClient {
  final RestClient client;
  String _token;
  KeyPair _private;
  
  DuseClient(Uri baseUri, ClientFactory clientFactory)
      : client = initializeClient(baseUri, clientFactory);
  
  Map<String, String> get authorizationHeader =>
      {"authorization": _token};
  
  static RestClient initializeClient(Uri baseUri,
                                     ClientFactory clientFactory) {
    var client = new RestClient(baseUri, clientFactory);
    var users = new ResourceBuilder(client, "users")
                      .addTypedProperty("id", type: int)
                      .addTypedProperty("username", type: String)
                      .addProperty("public_key",
                          inTransformer: (key) => KeyPair.parsePem(key))
                      .addTypedProperty("email", type: String)
                      .build();
    var secrets = new ResourceBuilder(client, "secrets")
                      .addTypedProperty("id", type: int)
                      .addTypedProperty("title", type: String)
                      .addProperty("shares",
                          inTransformer: (shares) =>
                              new decoder.DuseSecret.raw(shares))
                      .addProperty("url",
                          inTransformer: (uri) => Uri.parse(uri))
                      .addProperty("users",
                          inTransformer: (List userList) =>
                              userList.map(users.transformIn))
                      .build();
    return client
      ..addResource(users)
      ..addResource(secrets);
  }
  
  void set privateKey(key) {
    if (key is String) {
      _private = KeyPair.parsePem(key);
      return;
    }
    if (key is KeyPair) {
      _private = key;
      return;
    }
    throw new ArgumentError.value(key, "private key",
        "Only Strings or KeyPairs are supported");
  }
  
  Future<Entity> getDecodedSecret(int id) {
    checkPrivateKey();
    return getSecret(id).then((secret) {
      var decoded = new decoder.DuseSecret(secret.shares).decode(_private);
      return decoded;
    });
  }
  
  Future<Entity> createUser(String username, String password, String publickey) {
    return client.slash("users").create(body: {"username": username,
                                               "password": password,
                                               "public_key": publickey});
  }
  
  Future<Entity> getServerUser() {
    checkLoggedIn();
    return client.slash("users").slash("server").one(headers: authorizationHeader);
  }
  
  Future<Entity> getCurrentUser() {
    checkLoggedIn();
    return client.slash("users").slash("me").one(headers: authorizationHeader);
  }
  
  Future deleteUser(int id) {
    checkLoggedIn();
    return client.slash("users").delete(headers: authorizationHeader);
  }
  
  Future<Entity> createSecret(String title, String secret, List<int> userIds) {
    checkLoggedIn();
    checkPrivateKey();
    return Future.wait(userIds.map((id) => client.users(id,
        headers: authorizationHeader))).then((users) {
      var information = users.map((user) =>
          new encoder.UserEncryptionInformation(user.id, user.public_key))
                             .toList();
      var encoded = new encoder.DuseSecret(title, secret, information, _private);
      return client.slash("secrets").create(body: encoded.toJson(), headers: authorizationHeader)
          .catchError((StatusException ex) {
        print(ex.response.body);
      });
    });
  }
  
  Future login(String username, String email, String password) {
    return client.post("users/token",
        body: {"username" : username,
               "password" : password,
               "email"    : email}).then((response) {
      checkResponse(response, 201);
      return _token = JSON.decode(response.body)["api_token"];
    });
  }
  
  Future getSecret(int id) {
    checkLoggedIn();
    return client.slash("secret").id(id).one(headers: authorizationHeader);
  }
  
  Future deleteSecret(int id) {
    checkLoggedIn();
    return client.slash("secrets").id(id).delete(headers: authorizationHeader);
  }
  
  Future<List> listSecrets() {
    checkLoggedIn();
    return client.slash("secrets").all(headers: authorizationHeader);
  }
  
  Future<List> listUsers() {
    checkLoggedIn();
    return client.slash("users").all(headers: authorizationHeader);
  }
  
  void checkLoggedIn() {
    if (null == _token) throw new NotLoggedInException();
  }
  
  void checkPrivateKey() {
    if (null == _private) throw new KeysMissingException.private();
  }
}

class KeysMissingException implements Exception {
  final String _which;
  
  KeysMissingException.private() : _which = "Private";
  KeysMissingException.public() : _which = "Public";
  
  toString() => "$_which key is missing for encryption";
}


class NotLoggedInException implements Exception {
  toString() => "Not logged in";
}