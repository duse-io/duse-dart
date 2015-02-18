library duse.client;

import 'dart:async' show Future;
import 'dart:convert' show JSON;

import 'duse_secret_decoder.dart' as decoder;
import 'duse_secret_encoder.dart' as encoder;

import 'package:restpoint/restpoint.dart';
import 'package:rsa/rsa.dart';

class DuseClient {
  final RestClient client;
  String token;
  KeyPair _private;
  
  DuseClient(Uri baseUri, ClientFactory clientFactory)
      : client = initializeClient(baseUri, clientFactory);
  
  Map<String, String> get authorizationHeader =>
      {"authorization": token};
  
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
                      .addProperty("parts",
                          inTransformer: (parts) =>
                              new decoder.DuseSecret.raw(parts))
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
  
  Future<String> getDecodedSecret(int id) {
    checkPrivateKey();
    return getSecret(id).then((secret) {
      return secret.parts.decode(_private);
    });
  }
  
  Future<Entity> createUser(String username, String password,
                            String email, String publickey) {
    return client.slash("users").create(body: {"username" : username,
                                               "password" : password,
                                               "email"    : email,
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
  
  Future<Entity> getUser(int id) {
    checkLoggedIn();
    return client.slash("users").id(id).one(headers: authorizationHeader);
  }
  
  Future<Entity> updateUser(int id, Map<String, dynamic> values) {
    checkLoggedIn();
    return client.slash("users").id(id).patch(body: values, headers: authorizationHeader);
  }
  
  Future confirmUser(String token) {
    return client.patch("users/confirm", body: {"token": token})
                 .then((response) {
      checkResponse(response, 204);
    });
  }
  
  Future<String> forgotPassword(String email) {
    return client.post("users/forgot_password", body: {"email": email})
                 .then((response) {
      checkResponse(response, 201);
    });
  }
  
  Future changePassword(String token, String newPassword) {
    return client.slash("users").patch(body: {"token": token, "password": newPassword});
  }
  
  Future resendConfirmation(String email) {
    return client.post("users/confirm", body: {"email": email})
                 .then((response) {
      checkResponse(response, 201);
    });
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
  
  Future<String> login(String username, String password) {
    return client.post("users/token",
        body: {"username" : username,
               "password" : password}).then((response) {
      checkResponse(response, 201);
      return token = JSON.decode(response.body)["api_token"];
    });
  }
  
  Future getSecret(int id) {
    checkLoggedIn();
    return client.slash("secrets").id(id).one(headers: authorizationHeader);
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
  
  bool get isLoggedIn => null != token;
  bool get hasPrivateKey => null != _private;
  
  void checkLoggedIn() {
    if (!isLoggedIn) throw new NotLoggedInException();
  }
  
  void checkPrivateKey() {
    if (!hasPrivateKey) throw new KeysMissingException.private();
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