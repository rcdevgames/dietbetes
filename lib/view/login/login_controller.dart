import 'dart:io';
import 'dart:async';

import 'package:dietbetes/models/user.dart';
import 'package:dietbetes/util/api.dart';
import 'package:dietbetes/util/session.dart';
import 'package:flutter/material.dart';

import 'package:rxdart/rxdart.dart';
import 'package:dio/dio.dart';
import 'package:dietbetes/util/bloc.dart';

class LoginCtrl extends Object implements BlocBase {
  final _emailCtrl = BehaviorSubject<String>();
  final _passwordCtrl = BehaviorSubject<String>();
  final _loadingCtrl = BehaviorSubject<bool>();
  static Timer _timer;

  Stream<String> get email => _emailCtrl.stream;
  Stream<String> get password => _passwordCtrl.stream;
  Stream<bool> get isLoading => _loadingCtrl.stream;
  
  Stream<bool> get submitValid => Observable.combineLatest2(email, password, (e,p) => true);

  Function(String) get updateEmail => _emailCtrl.sink.add;
  Function(String) get updatePassword => _passwordCtrl.sink.add;
  Function(bool) get updateIsLoading => _loadingCtrl.sink.add;

  @override
  void dispose() {
    _emailCtrl.close();
    _passwordCtrl.close();
    _loadingCtrl.close();
  }

  Future checkLogin(BuildContext context) async {
    bool isLoggedIn = await sessions.checkAuth();
    if (isLoggedIn) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
    }
  }
  

  // Function
  Future<bool> checkConnection(GlobalKey<FormState> key) async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('connected');
      }
      return true;
    } on SocketException catch (_) {
      Scaffold.of(key.currentContext).showSnackBar(SnackBar(content: Text("No Internet connection !")));
      return false;
    }
  }

  Future fakeLogin(GlobalKey<FormState> key) async {
    FocusScope.of(key.currentContext).requestFocus(new FocusNode());
    if (key.currentState.validate()) {
      key.currentState.save();
      _loadingCtrl.sink.add(true);
      bool connect = await checkConnection(key);
      if (connect) {
        _timer?.cancel();
        _timer = new Timer(new Duration(seconds: 3), () {
          _loadingCtrl.sink.add(false);
          Navigator.of(key.currentContext).pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
        });
      }
    }
  }

  Future doLogin(GlobalKey<FormState> key) async {
    FocusScope.of(key.currentContext).requestFocus(new FocusNode());

    if (key.currentState.validate()) {
      key.currentState.save();
      _loadingCtrl.sink.add(true);
      var token = await sessions.load('onesignal');
      var api = Api.access();
      Response response;

      try {
        print('OnesignalToken : $token');
        response = await api.post("/auth/login", data: {
          "useremail" : _emailCtrl.value,
          "password": _passwordCtrl.value,
          "onesignal_token": token
        });
        
        _loadingCtrl.sink.add(false);
        print(response.data);
        Scaffold.of(key.currentContext).showSnackBar(SnackBar(content: Text("Login Success")));
        sessions.save("auth", userToJson(response.data['data']));
        var user = User.fromJson(response.data['data']);

        sessions.save("token", user.token);
        // print(await sessions.load('token'));
        // _loadingCtrl.sink.add(false);
        Navigator.of(key.currentContext).pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
      } on DioError catch (e) {
        _loadingCtrl.sink.add(false);
        if (e.response != null) {
          var message = "Something when wrong!";
          if (e.response.data.containsKey('validators')) {
            message = e.response.data['validators'].toString();
          }else if (e.response.data.containsKey('message')) {
            message = e.response.data['message'];
          }
          Scaffold.of(key.currentContext).showSnackBar(SnackBar(content: Text(message)));
        }else{
          Scaffold.of(key.currentContext).showSnackBar(SnackBar(content: Text(e.message)));
        }

      }
    }
  }
  // End Function
}