library all_tests;

import 'duse_client_test.dart' as client_tests;
import 'duse_secret_encoder_test.dart' as encoder_tests;
import 'duse_secret_decoder_test.dart' as decoder_tests;

void main() {
  client_tests.defineTests();
  encoder_tests.defineTests();
  decoder_tests.defineTests();
}
