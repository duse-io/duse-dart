import 'dart:io' show stdin, File, Platform;
import 'dart:convert' show JSON;

import 'package:restpoint/restpoint.dart';
import 'package:restpoint/restpoint_server_client.dart';
import 'package:unscripted/unscripted.dart';

import 'package:duse/duse.dart';

main(arguments) {
  var client = declare(CommandLineClient).execute(arguments);
}

class CommandLineClient {
  Map<String, dynamic> _config = _readConfig();
  
  final DuseClient client = new DuseClient(
      Uri.parse("http://duse.herokuapp.com/v1"),
      new ServerClientFactory());
  
  @Command(
      help: "Your friendly duse command line client")
  CommandLineClient();
  
  @SubCommand(
      help: "Login to your duse instance")
  login() {
    print("Enter username");
    var username = stdin.readLineSync();
    print("Enter password");
    stdin.echoMode = false;
    var password = stdin.readLineSync();
    stdin.echoMode = true;
    return client.login(username, password).then((token) {
      _config["token"] = token;
      print("Login successfull");
      _writeConfig();
    }).catchError((e) {
      print("Login errored: $e");
    });
  }
  
  @SubCommand(
      help: "Lists all users on your duse instance")
  listUsers() {
    _prepareForAuthorizedAction();
    client.listUsers().then(_printEntities);
  }
  
  @SubCommand(
      help: "List all secrets available for you")
  listSecrets() {
    _prepareForAuthorizedAction();
    client.listSecrets().then(_printEntities);
  }
  
  @SubCommand(
      help: "Get the specified secret")
  getSecret(
      @Rest(help: "The numerical id") List<String> id) {
    _prepareForAuthorizedAction();
    var _id = int.parse(id.single);
    client.getSecret(_id).then(print);
  }
  
  @SubCommand(
      help: "Get the specified secret and decode it")
  getDecodedSecret(
      @Rest(help: "The numerical id") List<String> id) {
    _prepareForAuthorizedAction();
    var _id = int.parse(id.single);
    client.privateKey = _privateKey;
    client.getDecodedSecret(_id).then(print);
  }
  
  @SubCommand(
      help: "Create a new secret")
  createSecret() async {
    _prepareForAuthorizedAction();
    String title = prompt("Please enter your title");
    String content = prompt("Please enter the secret's content");
    List<Entity> selectedUsers =
        [await client.getCurrentUser(), await client.getServerUser()];
    
    equals(int id1, int id2) => id1 == id2;
    if (promptDecision("Do you want to share the secret?")) {
      List<Entity> users = await client.listUsers() as List<Entity>;
      users.removeWhere((e) => selectedUsers.any((s) => equals(s.id, e.id)));
      print("Choose user[s] (separate multiple with ',')");
      print(users.map((user) => "${user.id}: ${user.username}").join("\n"));
      var chosen = stdin.readLineSync()
                        .split(",")
                        .map((str) => int.parse(str, onError: (s) => -1));
      selectedUsers.addAll(users.where((user) => chosen.any((n) =>
          equals(user.id, n))));
    }
    
    this.client.privateKey = _privateKey;
    this.client.createSecret(title, content,
        selectedUsers.map((u) => u.id).toList()).then((secret) {
      print("Created secret with title ${secret.title} and id ${secret.id}");
    });
  }
  
  String prompt(String question, {bool echoMode: true}) {
    print(question);
    var temp = stdin.echoMode;
    stdin.echoMode = echoMode;
    var answer = stdin.readLineSync();
    stdin.echoMode = temp;
    return answer;
  }
  
  bool promptDecision(String decision, {bool yesDefault: true}) {
    var append = yesDefault ? "[Y/n]" : "[y/N]";
    print("$decision $append");
    var answer = stdin.readLineSync().toLowerCase();
    if ("" == answer) return yesDefault;
    return "y" == answer;
  }
  
  String get _privateKey {
    return
"""-----BEGIN RSA PRIVATE KEY-----
MIIBOwIBAAJBANg8PKyzt2ehAg+UfKIBIBC6SU2GvaHv1Dc1e5HVweYbEjhM08Af
YoMSpe8VzwA/YsT2uDW7s+qZQJ+H5YP6aZECAwEAAQJBAKDCL82pkrnNXu3cU8hR
k9g71pF3kfYZiik9bs/eHliF+8CnZqrKOF3Ys7FqWCAbrsOQC1wWNjIaAWfpVtX7
4AECIQDzEDobsU+I8JaYPs2Gy1H54OkyUDADm+T7tBdt4bc/kQIhAOO+eTtZPk7V
vOXbH/VjRo7rXMcVsSut8iPRlwzYj4oBAiB+Tohjq5gxCRS4uKoEydMnjoCf7JuG
xJQRWFx0dT7MgQIgaH+Ccvfs/hFWnoVf8aF+w589L+BFLgyfeU33KB7KJgECIQCS
6JXBqbe3BftpS7otUsuZAdRijbeU60OGGwhsVX0pEw==
-----END RSA PRIVATE KEY-----""";
  }
  
  _printEntities(List<Entity> entities) {
    print(entities.map((user) => user.toString())
                  .join("\n\n"));
  }
  
  _prepareForAuthorizedAction() {
    var token = _config["token"];
    if (null == token) throw new NotLoggedInException();
    client.token = token;
  }
  
  static Map<String, dynamic> _readConfig() {
    if (new File("./.config").existsSync()) return readJson("./.config");
    new File("./.config").createSync();
    return {};
  }
  
  _writeConfig() {
    var file = new File("./.config");
    if (!file.existsSync()) file.createSync();
    file.writeAsStringSync(JSON.encode(_config));
  }
}

Map<String, dynamic> readJson(handle) {
  File file = handle is File ? handle : handle is String ? new File(handle) :
    throw new ArgumentError.value(handle);
  var content = file.readAsStringSync();
  return JSON.decode(content);
}