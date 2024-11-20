import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../exceptions.dart' show 
  UserDoesNotExistException,
  ServerErrorException,
  WrongPasswordException,
  UserAlreadyExistsException,
  InvalidPasswordException,
  InvalidUsernameException;
import '../client.dart' show ApiClient;
import 'core.dart' show ClientAppBar;


class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.onSuccess, this.onCancelled});

  final VoidCallback? onSuccess;
  final VoidCallback? onCancelled;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {

  late TextEditingController _passwordController;
  late TextEditingController _usernameController;

  final _formKey = GlobalKey<FormState>();

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();

  String? _mainError;
  String? _usernameError;
  String? _passwordError;
  bool _processing = false;
  Future<void>? _future;

  @override
  void initState() {
    super.initState();

    _passwordController = TextEditingController();
    _usernameController = TextEditingController();
  }

  void _onLoginPressed() {
    setState(() {
      _processing = true;
      _usernameError = _passwordError = _mainError = null;
      _future = Provider.of<ApiClient>(context, listen: false).connect(_usernameController.text, _passwordController.text);
      _future!.then((_) {
        widget.onSuccess?.call();
      }, onError: (e) {
        setState(() {
          _processing = false;
          switch (e) {
            case UserDoesNotExistException _:
              _usernameController.text = "";
              _passwordController.text = "";
              _mainError = "User does not exist";
              _usernameError = "";
              _passwordError = "";
              _usernameFocusNode.requestFocus();
            case ServerErrorException _:
              _mainError = "Something went wrong on the server";
            case WrongPasswordException _:
              _passwordController.text = "";
              _mainError = "Wrong password";
              _passwordError = "";
              _passwordFocusNode.requestFocus();
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _usernameController.dispose();
    _passwordFocusNode.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _processing
      ? FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Text("");
        }
      )
      : Form(
        key: _formKey,  
        child: SizedBox(
          width: 240, 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _mainError != null 
                ? Text(
                  _mainError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
                : const SizedBox(),
              TextFormField(
                autofocus: true,
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                decoration: InputDecoration(
                  labelText: 'Username',
                  errorText: _usernameError
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _passwordError
                ),
                textInputAction: TextInputAction.done,
                onEditingComplete: _onLoginPressed,
              ),
              const SizedBox(height: 32),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    OutlinedButton(
                      onPressed: () { widget.onCancelled?.call(); },
                      child: const Text("Cancel")
                    ),
                    FilledButton(
                      onPressed: _onLoginPressed,
                      child: const Text("Log in")
                    ),
                  ]
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    InkWell(
                      child: Text(
                        "Sign up",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          decoration: TextDecoration.underline
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Material(
                              child: Center(
                                child: RegisterForm(
                                  onSuccess: () {
                                    Navigator.of(context).pop();
                                    widget.onSuccess?.call();
                                  },
                                  onCancelled: () {
                                    Navigator.of(context).pop();
                                    widget.onCancelled?.call();
                                  },
                                ),
                              )
                            )
                          ),
                        );
                      },
                    )
                  ]
                )
            ]
          )
        )
      );
  }
}


class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key, this.onSuccess, this.onCancelled});

  final VoidCallback? onSuccess;
  final VoidCallback? onCancelled;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  late TextEditingController _passwordController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordRepeatController;

  final _formKey = GlobalKey<FormState>();

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordRepeatFocusNode = FocusNode();

  String? _mainError;
  String? _usernameError;
  String? _passwordError;
  String? _passwordRepeatError;

  bool _processing = false;
  Future<void>? _future;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordRepeatController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _usernameController.dispose();
    _passwordRepeatController.dispose();
    _passwordFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordRepeatFocusNode.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _processing = true;
        _mainError = _usernameError = _passwordError = null;
        _future = Provider.of<ApiClient>(context, listen: false).create(_usernameController.text, _passwordController.text);
        _future!.then(
          (_) {
            widget.onSuccess?.call();
          },
          onError: (e) {
            setState(() {
              _processing = false;
              switch (e) {
                case ServerErrorException _:
                  _mainError = "Something went wrong on the server";
                  break;
                case UserAlreadyExistsException _:
                  _usernameController.text = "";
                  _passwordController.text = "";
                  _passwordRepeatController.text = "";
                  _mainError = "User already exists, if it's you, go to Log In page";
                  _usernameFocusNode.requestFocus();
                  break;
                case InvalidPasswordException _:
                  _passwordController.text = "";
                  _passwordRepeatController.text = "";
                  _mainError = "Password must be at least 8 and at most 32 characters long, contain at least one letter and one number";
                  _passwordError = "";
                  _passwordRepeatError = "";
                  _passwordFocusNode.requestFocus();
                  break;
                case InvalidUsernameException _:
                  _usernameController.text = "";
                  _passwordController.text = "";
                  _passwordRepeatController.text = "";
                  _mainError = "Username must be at least 3 and at most 32 characters long";
                  _usernameError = "";
                  _usernameFocusNode.requestFocus();
                  break;
              }
            });
          }
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _processing
     ? FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Text("");
        }
      )
      : Form(
        key: _formKey,  
        child: SizedBox(
          width: 240, 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _mainError != null 
                ? Text(
                  _mainError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
                : const SizedBox(),
              TextFormField(
                autofocus: true,
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                decoration: InputDecoration(
                  labelText: 'Username',
                  errorText: _usernameError
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _passwordError
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordRepeatController,
                focusNode: _passwordRepeatFocusNode,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Repeat password',
                  errorText: _passwordRepeatError
                ),
                textInputAction: TextInputAction.done,
                onEditingComplete: _onRegisterPressed,
                validator: (value) => _passwordController.text != _passwordRepeatController.text ? "Passwords do not match" : null
              ),
              const SizedBox(height: 32),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    OutlinedButton(
                      onPressed: widget.onCancelled,
                      child: const Text("Cancel")
                    ),
                    FilledButton(
                      onPressed: _onRegisterPressed,
                      child: const Text("Sign up")
                    )
                  ]
              ),
              const SizedBox(height: 16),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    InkWell(
                      child: Text(
                        "Log in",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          decoration: TextDecoration.underline
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Material(
                              child: Center(
                                child: LoginForm(
                                  onSuccess: () {
                                    Navigator.of(context).pop();
                                    widget.onSuccess?.call();
                                  },
                                  onCancelled: () {
                                    Navigator.of(context).pop();
                                    widget.onCancelled?.call();
                                  },
                                ),
                              )
                            )
                          ),
                        );
                      },
                    )
                  ]
                )
            ]
          )
        )
      );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ClientAppBar(title: "TreeBook"),
      body: Center(
        child: LoginForm(
          onSuccess: () {
            Navigator.of(context).pop();
            onSuccess?.call();
          },
          onCancelled: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ClientAppBar(title: "TreeBook"),
      body: Center(
        child: RegisterForm(
          onSuccess: () {
            Navigator.of(context).pop();
          },
          onCancelled: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}