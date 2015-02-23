# duse
[![Coverage Status](https://coveralls.io/repos/duse-io/duse-dart/badge.svg?branch=master)](https://coveralls.io/r/duse-io/duse-dart?branch=master)
> **Warning:** This implementation has not been tested in production nor has it been examined by a security audit.
> All uses are your own responsibility.

The duse client written for dart. This client has all methods which are required to use
the duse api.

To logon, simply use the `DuseClient.login` method. After that, you can use all other methods.
If you don't have an account yet, you can change that with `DuseClient.createUser`. After that,
a confirmation mail will be sent to your email.
