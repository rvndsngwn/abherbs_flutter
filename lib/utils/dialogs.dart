import 'dart:async';
import 'dart:io';

import 'package:abherbs_flutter/generated/l10n.dart';
import 'package:abherbs_flutter/settings/settings_remote.dart';
import 'package:abherbs_flutter/utils/utils.dart';
import 'package:abherbs_flutter/utils/prefs.dart';
import 'package:flutter/material.dart';

Future<void> rateDialog(BuildContext context) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(S.of(context).rate_question),
        content: Text(S.of(context).rate_text),
        actions: <Widget>[
          FlatButton(
            child: Text(S.of(context).rate_never),
            onPressed: () {
              Prefs.setString(keyRateState, rateStateNever);
              Navigator.of(context).pop();
            },
          ),
          FlatButton(
            child: Text(S.of(context).rate_later),
            onPressed: () {
              Prefs.setString(keyRateCount, rateCountInitial.toString());
              Prefs.setString(keyRateState, rateStateInitial);
              Navigator.of(context).pop();
            },
          ),
          FlatButton(
            child: Text(S.of(context).rate),
            onPressed: () {
              Prefs.setString(keyRateState, rateStateDid);
              Navigator.of(context).pop();
              if (Platform.isAndroid) {
                launchURL(playStore);
              } else {
                launchURL(appStore);
              }
            },
          ),
        ],
      );
    },
  );
}

Future<void> observationDialog(BuildContext mainContext, GlobalKey<ScaffoldState> key) async {
  return showDialog(
      context: mainContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.of(context).observations),
          content: Text(S.of(context).observation_no_login),
          actions: [
            FlatButton(
              child: Text(S.of(context).close.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop();
                if (key.currentState != null) {
                  key.currentState.openDrawer();
                }
              },
            )
          ],
        );
      });
}

Future<void> photoSearchDialog(BuildContext mainContext, GlobalKey<ScaffoldState> key) async {
  return showDialog(
      context: mainContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.of(context).product_photo_search_title),
          content: Text(S.of(context).photo_search_no_login),
          actions: [
            FlatButton(
              child: Text(S.of(context).close.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop();
                if (key.currentState != null) {
                  key.currentState.openDrawer();
                }
              },
            )
          ],
        );
      });
}

Future<void> favoriteDialog(BuildContext mainContext, GlobalKey<ScaffoldState> key) async {
  return showDialog(
      context: mainContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.of(context).favorite_title),
          content: Text(S.of(context).favorite_no_login),
          actions: [
            FlatButton(
              child: Text(S.of(context).close.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop();
                if (key.currentState != null) {
                  key.currentState.openDrawer();
                }
              },
            )
          ],
        );
      });
}

Future<bool> deleteDialog(BuildContext mainContext, String title, String content) async {
  return showDialog(
      context: mainContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            FlatButton(
              child: Text(S.of(context).yes.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            FlatButton(
              child: Text(S.of(context).no.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            )
          ],
        );
      });
}

Future<bool> subscriptionDialog(BuildContext mainContext, String title, String content) async {
  return showDialog(
      context: mainContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            FlatButton(
              child: Text(S.of(context).product_subscribe.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            FlatButton(
              child: Text(S.of(context).close.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            )
          ],
        );
      });
}

Future<bool> infoDialog(BuildContext mainContext, String title, String content) async {
  return showDialog(
      context: mainContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            FlatButton(
              child: Text(S.of(context).close.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      });
}

Future<bool> infoBuyDialog(BuildContext mainContext, String title, String content, String config) async {
  Widget button = Container();
  String value = RemoteConfiguration.remoteConfig.getString(config);
  if (value.isNotEmpty) {
    button = FlatButton(
      color: Colors.lightBlueAccent,
      child: Text(S
          .of(mainContext)
          .video,
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          )),
      onPressed: () {
        launchURL(value);
      },
    );
  }

  return showDialog(
      context: mainContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content),
              button,
            ],
          ),
          actions: [
            FlatButton(
              child: Text(S.of(context).enhancements.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            FlatButton(
              child: Text(S.of(context).close.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  )),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
          ],
        );
      });
}
