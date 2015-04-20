library duse.test.client;

import 'dart:convert' show Encoding;
import 'dart:async' show Future;

import 'package:duse/duse.dart';

import 'package:rsa/rsa.dart' show KeyPair, Key;
import 'package:restpoint/restpoint.dart';
import 'package:mock/mock.dart';
import 'package:unittest/unittest.dart';

import 'mock.dart';

final TEST_URI = Uri.parse("http://example.org");

final pubkey =
    "-----BEGIN PUBLIC KEY-----\\n" +
    "MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBANg8PKyzt2ehAg+UfKIBIBC6SU2GvaHv\\n" +
    "1Dc1e5HVweYbEjhM08AfYoMSpe8VzwA/YsT2uDW7s+qZQJ+H5YP6aZECAwEAAQ==\\n" +
    "-----END PUBLIC KEY-----";

final pubkeyInstance = KeyPair.parsePem(
"""-----BEGIN PUBLIC KEY-----
MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBANg8PKyzt2ehAg+UfKIBIBC6SU2GvaHv
1Dc1e5HVweYbEjhM08AfYoMSpe8VzwA/YsT2uDW7s+qZQJ+H5YP6aZECAwEAAQ==
-----END PUBLIC KEY-----""");

var privkey =
"""-----BEGIN RSA PRIVATE KEY-----
MIIBOwIBAAJBANg8PKyzt2ehAg+UfKIBIBC6SU2GvaHv1Dc1e5HVweYbEjhM08Af
YoMSpe8VzwA/YsT2uDW7s+qZQJ+H5YP6aZECAwEAAQJBAKDCL82pkrnNXu3cU8hR
k9g71pF3kfYZiik9bs/eHliF+8CnZqrKOF3Ys7FqWCAbrsOQC1wWNjIaAWfpVtX7
4AECIQDzEDobsU+I8JaYPs2Gy1H54OkyUDADm+T7tBdt4bc/kQIhAOO+eTtZPk7V
vOXbH/VjRo7rXMcVsSut8iPRlwzYj4oBAiB+Tohjq5gxCRS4uKoEydMnjoCf7JuG
xJQRWFx0dT7MgQIgaH+Ccvfs/hFWnoVf8aF+w589L+BFLgyfeU33KB7KJgECIQCS
6JXBqbe3BftpS7otUsuZAdRijbeU60OGGwhsVX0pEw==
-----END RSA PRIVATE KEY-----""";

equalKeyPairs(KeyPair p1, KeyPair p2) {
  if (p1.public == null && p2.public != null ||
      p1.public != null && p2.public == null) return false;
  if (p1.private == null && p2.private != null ||
      p1.private != null && p2.private == null) return false;
  
  if (p1.public != null) {
    if (!equalKeys(p1.public, p2.public)) return false;
  }
  if (p1.private != null) {
    if (!equalKeys(p1.private, p2.private)) return false;
  }
  return true;
}

equalKeys(Key k1, Key k2) {
  return k1.exponent == k2.exponent && k1.modulus == k2.modulus;
}

defineTests() {
  group("DuseClient", () {
    test("isLoggedIn", () {
      var client = new DuseClient(null, null);
            
      expect(client.isLoggedIn, isFalse);
      
      client.token = "token";
      expect(client.isLoggedIn, isTrue);
    });
    
    test("checkLoggedIn", () {
      var client = new DuseClient(null, null);
      
      expect(() => client.checkLoggedIn(), throws);
      
      client.token = "token";
      expect(() => client.checkLoggedIn(), returnsNormally);
    });
    
    test("hasPrivateKey", () {
      var mock = new KeyPairMock();
      var client = new DuseClient(null, null);
      
      expect(client.hasPrivateKey, isFalse);
      
      client.privateKey = mock;
      expect(client.hasPrivateKey, isTrue);
    });
    
    test("checkPrivateKey", () {
      var mock = new KeyPairMock();
      var client = new DuseClient(null, null);
      
      expect(() => client.checkPrivateKey(), throws);
      
      client.privateKey = mock;
      expect(() => client.checkPrivateKey(), returnsNormally);
    });
    
    test("createUser", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn('{"id": 3,' +
                     '"username": "adracus", ' +
                     '"email":"some@mail.de", ' +
                     '"public_key": "$pubkey"}')
        ..when(callsTo("get statusCode"))
         .thenReturn(201);
      var client = new ClientMock()
        ..handlers["post"] = (url, {Map<String, String> headers,
                                    body, Encoding encoding}) {
        expect(headers, equals({"content-type": "application/json"}));
        expect(url, equals(Uri.parse("http://example.org/users")));
        expect(encoding, isNull);
        expect(body, equals('{"username":"adracus","password":"password",' +
            '"email":"some@mail.de","public_key":"pubkey"}'));
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.createUser("adracus", "password", "some@mail.de", "pubkey")
          .then((expectAsync((Entity user) {
        expect(user.id, equals(3));
        expect(user.username, equals("adracus"));
        expect(user.email, equals("some@mail.de"));
        expect(equalKeyPairs(user.public_key, pubkeyInstance), isTrue);
        
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("getServerUser", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn('{"id": 1,' +
                     '"username": "server", ' +
                     '"email":"server@localhost", ' +
                     '"public_key": "$pubkey"}')
        ..when(callsTo("get statusCode"))
         .thenReturn(200);
      var client = new ClientMock()
        ..handlers["get"] = (url, {Map<String, String> headers,
                                   Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token"
        }));
        expect(url, equals(Uri.parse("http://example.org/users/server")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.getServerUser()
          .then((expectAsync((Entity user) {
        expect(user.id, equals(1));
        expect(user.username, equals("server"));
        expect(user.email, equals("server@localhost"));
        expect(equalKeyPairs(user.public_key, pubkeyInstance), isTrue);
        
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("getCurrentUser", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn('{"id": 3,' +
                     '"username": "adracus", ' +
                     '"email":"some@mail.de", ' +
                     '"public_key": "$pubkey"}')
        ..when(callsTo("get statusCode"))
         .thenReturn(200);
      var client = new ClientMock()
        ..handlers["get"] = (url, {Map<String, String> headers,
                                   Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token"
        }));
        expect(url, equals(Uri.parse("http://example.org/users/me")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.getCurrentUser()
          .then((expectAsync((Entity user) {
        expect(user.id, equals(3));
        expect(user.username, equals("adracus"));
        expect(user.email, equals("some@mail.de"));
        expect(equalKeyPairs(user.public_key, pubkeyInstance), isTrue);
        
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("getUser", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn('{"id": 3,' +
                     '"username": "adracus", ' +
                     '"email":"some@mail.de", ' +
                     '"public_key": "$pubkey"}')
        ..when(callsTo("get statusCode"))
         .thenReturn(200);
      var client = new ClientMock()
        ..handlers["get"] = (url, {Map<String, String> headers,
                                   Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token"
        }));
        expect(url, equals(Uri.parse("http://example.org/users/3")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.getUser(3)
          .then((expectAsync((Entity user) {
        expect(user.id, equals(3));
        expect(user.username, equals("adracus"));
        expect(user.email, equals("some@mail.de"));
        expect(equalKeyPairs(user.public_key, pubkeyInstance), isTrue);
        
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("updateUser", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn('{"id": 3,' +
                     '"username": "notAdracusAnymore", ' +
                     '"email":"some@mail.de", ' +
                     '"public_key": "$pubkey"}')
        ..when(callsTo("get statusCode"))
         .thenReturn(200);
      
      var clientFactory = new ClientFactoryMock()
        ..patchHandler = (url, {Map<String, String> headers,
                                body, Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token",
          "content-type": "application/json"
        }));
        expect(body, equals('{"username":"notAdracusAnymore"}'));
        expect(url, equals(Uri.parse("http://example.org/users/3")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.updateUser(3, {"username": "notAdracusAnymore"})
          .then((expectAsync((Entity user) {
        expect(user.id, equals(3));
        expect(user.username, equals("notAdracusAnymore"));
        expect(user.email, equals("some@mail.de"));
        expect(equalKeyPairs(user.public_key, pubkeyInstance), isTrue);
        
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("confirmUser", () {
      var response = new ResponseMock()
        ..when(callsTo("get statusCode"))
         .thenReturn(204);
      
      var clientFactory = new ClientFactoryMock()
        ..patchHandler = (url, {Map<String, String> headers,
                                body, Encoding encoding}) {
        expect(headers, equals({
          "content-type": "application/json"
        }));
        expect(body, equals('{"token":"confirmation"}'));
        expect(url, equals(Uri.parse("http://example.org/users/confirm")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.confirmUser("confirmation")
          .then((expectAsync((_) {
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("forgotPassword", () {
      var response = new ResponseMock()
        ..when(callsTo("get statusCode"))
         .thenReturn(201);
      var client = new ClientMock()
        ..handlers["post"] = (url, {Map<String, String> headers, body,
                                   Encoding encoding}) {
        expect(headers, equals({
          "content-type": "application/json"
        }));
        expect(body, equals('{"email":"some@mail.de"}'));
        expect(url,
            equals(Uri.parse("http://example.org/users/forgot_password")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.forgotPassword("some@mail.de")
          .then((expectAsync((Entity user) {
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("changePassword", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn('{"id": 3,' +
                     '"username": "notAdracusAnymore", ' +
                     '"email":"some@mail.de", ' +
                     '"public_key": "$pubkey"}')
        ..when(callsTo("get statusCode"))
         .thenReturn(200);
      
      var clientFactory = new ClientFactoryMock()
        ..patchHandler = (url, {Map<String, String> headers,
                                body, Encoding encoding}) {
        expect(headers, equals({
          "content-type": "application/json"
        }));
        expect(body, equals('{"token":"token","password":"nupassword"}'));
        expect(url, equals(Uri.parse("http://example.org/users")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.changePassword("token", "nupassword")
          .then((expectAsync((Entity user) {
        expect(user.id, equals(3));
        expect(user.username, equals("notAdracusAnymore"));
        expect(user.email, equals("some@mail.de"));
        expect(equalKeyPairs(user.public_key, pubkeyInstance), isTrue);
        
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("resendConfirmation", () {
      var response = new ResponseMock()
        ..when(callsTo("get statusCode"))
         .thenReturn(201);
      var client = new ClientMock()
        ..handlers["post"] = (url, {Map<String, String> headers, body,
                                   Encoding encoding}) {
        expect(headers, equals({
          "content-type": "application/json"
        }));
        expect(body, equals('{"email":"some@mail.de"}'));
        expect(url,
            equals(Uri.parse("http://example.org/users/confirm")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.resendConfirmation("some@mail.de")
          .then((expectAsync((Entity user) {
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("deleteUser", () {
      var response = new ResponseMock()
        ..when(callsTo("get statusCode"))
         .thenReturn(204);
      var client = new ClientMock()
        ..handlers["delete"] = (url, {Map<String, String> headers,
                                   Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token"
        }));
        expect(url,
            equals(Uri.parse("http://example.org/users/10")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.deleteUser(10)
          .then((expectAsync((_) {
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("resendConfirmation", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn('{"api_token": "thetoken"}')
        ..when(callsTo("get statusCode"))
         .thenReturn(201);
      var client = new ClientMock()
        ..handlers["post"] = (url, {Map<String, String> headers, body,
                                   Encoding encoding}) {
        expect(headers, equals({
          "content-type": "application/json"
        }));
        expect(body, equals('{"username":"adracus","password":"password"}'));
        expect(url,
            equals(Uri.parse("http://example.org/users/token")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.login("adracus", "password")
          .then((expectAsync((String token) {
        expect(token, equals("thetoken"));
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    /*test("getSecret", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn(
'{"id":21,"title":"A secret","parts":[["Z7wMFY8ZRyJ298WwtURzVwPULCRI4LngbjwvZ' +
'jrxuTr2bR+Ak1Rodj7y/7ZX\\ne1wS9Bzs0ijDA8hK2HdPohk4gQ==\\n","YCyplMgXg3yBkewBf5A6k' +
't/jgXAI6iunLNBxDZw81x4diO1C4GlQrQgipXRjH3GMgk1T7r2Y/Ddn7Y+51yQrbQ=="]],"users":' +
'[{"id":2,"username":"Adracus","email":"adracus@gmail.com","public_key":"-----BE' +
'GIN PUBLIC KEY-----\\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBANg8PKyzt2ehAg+UfKIBIBC6SU' +
'2GvaHv\\n1Dc1e5HVweYbEjhM08AfYoMSpe8VzwA/YsT2uDW7s+qZQJ+H5YP6aZECAwEAAQ==\\n-----' +
'END PUBLIC KEY-----\\n","url":"http://duse.herokuapp.com/v1/users/2"},{"id":3,"u' +
'sername":"server","email":"server@localhost","public_key":"-----BEGIN PUBLIC KE' +
'Y-----\\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC8i06KxN8syikxbV5POpFy637s\\novC9b' +
'ED3CZNBi0cvpyqRjTvr2GQaeLMA9oyenE5EWXZq5FZcPpIGAgnkNkd+Uliq\\nxFOobTJIlE4R+rqbc8' +
'qZq78V+6Qb8zHy7NRFt4tTfxCYlgkaLCkN3KAIUHSHqY7b\\n4yg9h522cRyXdqOODwIDAQAB\\n-----' +
'END PUBLIC KEY-----\\n","url":"http://duse.herokuapp.com/v1/users/3"}],"url":"ht' +
'tp://duse.herokuapp.com/v1/secrets/21"}')
        ..when(callsTo("get statusCode"))
         .thenReturn(200);
      var client = new ClientMock()
        ..handlers["get"] = (url, {Map<String, String> headers,
                                   Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token"
        }));
        expect(url,
            equals(Uri.parse("http://example.org/secrets/21")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.getSecret(21)
          .then((expectAsync((Entity secret) {
        expect(secret.id, equals(21));
        expect(secret.title, equals("A secret"));
        expect(secret.users.length, equals(2));
        expect(secret.users.first.id, equals(2));
        expect(secret.users.first.email, equals("adracus@gmail.com"));
        expect(secret.users.first.username, equals("Adracus"));
        expect(secret.users.last.id, equals(3));
        expect(secret.users.last.email, equals("server@localhost"));
        expect(secret.users.last.username, equals("server"));
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });*/
    
    test("deleteSecret", () {
      var response = new ResponseMock()
        ..when(callsTo("get statusCode"))
         .thenReturn(204);
      var client = new ClientMock()
        ..handlers["delete"] = (url, {Map<String, String> headers,
                                   Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token"
        }));
        expect(url,
            equals(Uri.parse("http://example.org/secrets/10")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.deleteSecret(10)
          .then((expectAsync((_) {
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("listSecrets", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn(
"""[{"id":18,"title":"Test","url":"http://duse.herokuapp.com/v1/secrets/18"},
{"id":19,"title":"Test","url":"http://duse.herokuapp.com/v1/secrets/19"},
{"id":21,"title":"A secret","url":"http://duse.herokuapp.com/v1/secrets/21"}]""")
        ..when(callsTo("get statusCode"))
         .thenReturn(200);
      var client = new ClientMock()
        ..handlers["get"] = (url, {Map<String, String> headers,
                                   Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token"
        }));
        expect(url, equals(Uri.parse("http://example.org/secrets")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.listSecrets()
          .then((expectAsync((List<Entity> secrets) {
        expect(secrets.length, equals(3));
        expect(secrets.first.id, equals(18));
        expect(secrets.first.title, equals("Test"));
        expect(secrets[1].id, equals(19));
        expect(secrets[1].title, equals("Test"));
        expect(secrets.last.id, equals(21));
        expect(secrets.last.title, equals("A secret"));
        
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    test("listSecrets", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn(
"""[{"id":1,"username":"flower-pot","email":"fbranczyk@some-mail.de"},
{"id":3,"username":"server","email":"server@localhost"},
{"id":2,"username":"Adracus","email":"adracus@some-mail.de"}]""")
        ..when(callsTo("get statusCode"))
         .thenReturn(200);
      var client = new ClientMock()
        ..handlers["get"] = (url, {Map<String, String> headers,
                                   Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token"
        }));
        expect(url, equals(Uri.parse("http://example.org/users")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.listUsers()
          .then((expectAsync((List<Entity> users) {
        expect(users.length, equals(3));
        expect(users.first.id, equals(1));
        expect(users.first.username, equals("flower-pot"));
        expect(users.first.email, equals("fbranczyk@some-mail.de"));
        expect(users[1].id, equals(3));
        expect(users[1].username, equals("server"));
        expect(users[1].email, equals("server@localhost"));
        expect(users.last.id, equals(2));
        expect(users.last.username, equals("Adracus"));
        expect(users.last.email, equals("adracus@some-mail.de"));
        
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });
    
    /*
    test("getSecret", () {
      var response = new ResponseMock()
        ..when(callsTo("get body"))
         .thenReturn(
'{"id":21,"title":"A secret","parts":[["Z7wMFY8ZRyJ298WwtURzVwPULCRI4LngbjwvZ' +
'jrxuTr2bR+Ak1Rodj7y/7ZX\\ne1wS9Bzs0ijDA8hK2HdPohk4gQ==\\n","YCyplMgXg3yBkewBf5A6k' +
't/jgXAI6iunLNBxDZw81x4diO1C4GlQrQgipXRjH3GMgk1T7r2Y/Ddn7Y+51yQrbQ=="]],"users":' +
'[{"id":2,"username":"Adracus","email":"adracus@gmail.com","public_key":"-----BE' +
'GIN PUBLIC KEY-----\\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBANg8PKyzt2ehAg+UfKIBIBC6SU' +
'2GvaHv\\n1Dc1e5HVweYbEjhM08AfYoMSpe8VzwA/YsT2uDW7s+qZQJ+H5YP6aZECAwEAAQ==\\n-----' +
'END PUBLIC KEY-----\\n","url":"http://duse.herokuapp.com/v1/users/2"},{"id":3,"u' +
'sername":"server","email":"server@localhost","public_key":"-----BEGIN PUBLIC KE' +
'Y-----\\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC8i06KxN8syikxbV5POpFy637s\\novC9b' +
'ED3CZNBi0cvpyqRjTvr2GQaeLMA9oyenE5EWXZq5FZcPpIGAgnkNkd+Uliq\\nxFOobTJIlE4R+rqbc8' +
'qZq78V+6Qb8zHy7NRFt4tTfxCYlgkaLCkN3KAIUHSHqY7b\\n4yg9h522cRyXdqOODwIDAQAB\\n-----' +
'END PUBLIC KEY-----\\n","url":"http://duse.herokuapp.com/v1/users/3"}],"url":"ht' +
'tp://duse.herokuapp.com/v1/secrets/21"}')
        ..when(callsTo("get statusCode"))
         .thenReturn(200);
      var client = new ClientMock()
        ..handlers["get"] = (url, {Map<String, String> headers,
                                   Encoding encoding}) {
        expect(headers, equals({
          "authorization": "token"
        }));
        expect(url,
            equals(Uri.parse("http://example.org/secrets/21")));
        expect(encoding, isNull);
        return new Future.value(response);
      };
      client.when(callsTo("close")).thenReturn(true);
      var clientFactory = new ClientFactoryMock()
        ..when(callsTo("createClient")).thenReturn(client);
      
      var duse = new DuseClient(TEST_URI, clientFactory);
      duse.token = "token";
      duse.privateKey = privkey;
      duse.getDecodedSecret(21)
          .then((expectAsync((String secret) {
        expect(secret, equals("Some content"));
        client.calls("close").verify(happenedOnce);
        clientFactory.calls("createClient").verify(happenedOnce);
        response.calls("get statusCode").verify(happenedOnce);
      })));
    });*/
    
    test("set privateKey", () {
      var client = new DuseClient(null, null);
      var mock = new KeyPairMock();
      
      expect(() => client.privateKey = 1, throws);
      expect(() => client.privateKey = privkey, returnsNormally);
      expect(() => client.privateKey = mock, returnsNormally);
    });
    
    test("logout", () {
      var client = new DuseClient(null, null);
      var mock = new KeyPairMock();
      
      client.privateKey = mock;
      client.token = "token";
      
      expect(client.privateKey, equals(mock));
      expect(client.token, equals("token"));
      
      client.logout();
      
      expect(client.privateKey, isNull);
      expect(client.token, isNull);
    });
  });
}