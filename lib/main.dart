import 'dart:async';
import 'dart:io';

import 'package:abherbs_flutter/generated/l10n.dart';
import 'package:abherbs_flutter/plant_list.dart';
import 'package:abherbs_flutter/purchase/purchases.dart';
import 'package:abherbs_flutter/settings/offline.dart';
import 'package:abherbs_flutter/settings/settings_remote.dart';
import 'package:abherbs_flutter/signin/authetication.dart';
import 'package:abherbs_flutter/splash.dart';
import 'package:abherbs_flutter/utils/prefs.dart';
import 'package:abherbs_flutter/utils/utils.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:screen/screen.dart';
import 'package:flutter_localized_countries/flutter_localized_countries.dart';

import 'ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() {
    initializeFlutterFire().then((_) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
          .then((_) {
        Screen.keepOn(true);
        InAppPurchaseConnection.enablePendingPurchases();
        Ads.initialize();
        runApp(App());
      }).catchError((error) {
        print('setOrientation: Caught error in set orientation.');
        FirebaseCrashlytics.instance.recordError(error, null);
      });
    }).catchError((error) {
      print('FlutterFire: Caught error in FlutterFire initialization.');
      FirebaseCrashlytics.instance.recordError(error, null);
    });
  }, (error, stackTrace) {
    print('runZonedGuarded: Caught error in my root zone.');
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
  });
}

// Define an async function to initialize FlutterFire
Future<void> initializeFlutterFire() async {
  // Wait for Firebase to initialize
  await Firebase.initializeApp();

  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!isInDebugMode);

  // Pass all uncaught errors to Crashlytics.
  Function originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails errorDetails) async {
    await FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
    // Forward to original handler.
    originalOnError(errorDetails);
  };
}

class App extends StatefulWidget {
  static BuildContext currentContext;
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  final FirebaseAnalytics _firebaseAnalytics = FirebaseAnalytics();

  StreamSubscription<List<PurchaseDetails>> _subscription;
  Map<String, dynamic> _notificationData;
  Future<Locale> _localeF;
  Future<void> _initStoreF;



  Future<void> _logFailedPurchaseEvent() async {
    await _firebaseAnalytics.logEvent(name: 'purchase_failed');
  }

  onChangeLanguage(String language) {
    setState(() {
      translationCache = {};
      _localeF = Future<Locale>(() {
        var languageCountry = language?.split('_');
        return language == null || language.isEmpty
            ? null
            : Locale(languageCountry[0], languageCountry[1]);
      });
    });
  }

  _listenToPurchaseUpdated(List<PurchaseDetails> purchases) {
    var isPurchase = false;
    for (PurchaseDetails purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased: {
          final pending = Platform.isIOS
              ? purchase.pendingCompletePurchase
              : !purchase.billingClientPurchase.isAcknowledged;
          if (pending) {
            InAppPurchaseConnection.instance.completePurchase(purchase);
          }
          Purchases.purchases.add(purchase);
          isPurchase = true;
        }
        break;

        case PurchaseStatus.error: {
          if (Platform.isIOS) {
            InAppPurchaseConnection.instance.completePurchase(purchase);
          }
        }
        break;

        default: {

        }
      }
    }
    if (isPurchase) {
      Prefs.setStringList(keyPurchases,
          Purchases.purchases.map((item) => item.productID).toList());
      setState(() {});
    }
  }

  void _firebaseCloudMessagingListeners() {
    if (Platform.isIOS) _iOSPermission();

    _firebaseMessaging.getToken().then((token) {
      Prefs.setString(keyToken, token);
      print('token $token');
    });

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        String notificationText = Platform.isIOS ? message['aps']['alert'] : message[notificationAttributeNotification][notificationAttributeBody];
        Map<String, dynamic> notificationData = Map.from(
            Platform.isIOS ? message : message[notificationAttributeData]);
        String action = notificationData[notificationAttributeAction];
        if (action != null && action == notificationAttributeActionList && App.currentContext != null) {
          String path = notificationData[notificationAttributePath];
          rootReference.child(path).keepSynced(true);
          return showDialog(
            context: App.currentContext,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(S.of(context).notification),
                content: Text(notificationText),
                actions: <Widget>[
                  FlatButton(
                    child: Text(S.of(context).notification_open, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold,)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => PlantList(onChangeLanguage, {}, '', rootReference.child(path)),
                          settings: RouteSettings(name: 'PlantList')));
                    },
                  ),
                  FlatButton(
                    child: Text(S.of(context).notification_close, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold,)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }
      },
      onResume: (Map<String, dynamic> message) async {
        setState(() {
          _notificationData = Map.from(
              Platform.isIOS ? message : message[notificationAttributeData]);
        });
      },
      onLaunch: (Map<String, dynamic> message) async {
        setState(() {
          _notificationData = Map.from(
              Platform.isIOS ? message : message[notificationAttributeData]);
        });
      },
    );
  }

  void _iOSPermission() {
    _firebaseMessaging.requestNotificationPermissions(
        IosNotificationSettings(sound: true, badge: true, alert: true));
    _firebaseMessaging.onIosSettingsRegistered
        .listen((IosNotificationSettings settings) {
      print("Settings registered: $settings");
    });
  }

  void _iapError() {
    Fluttertoast.showToast(
        msg: 'IAP not prepared. Check if Platform service is available.',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 5,
        backgroundColor: Colors.redAccent);
    Purchases.purchases = [];
  }

  void _checkPromotions() {
    rootReference
        .child(firebasePromotions)
        .once()
        .then((DataSnapshot snapshot) {
      if (snapshot.value != null) {
        if (snapshot.value[firebaseAttributeObservations] != null) {
          var observationsFrom = DateTime.parse(snapshot
              .value[firebaseAttributeObservations][firebaseAttributeFrom]);
          var observationsTo = DateTime.parse(snapshot
              .value[firebaseAttributeObservations][firebaseAttributeTo]);

          var currentDate = DateTime.now();
          Purchases.observationPromotionFrom = observationsFrom;
          Purchases.observationPromotionTo = observationsTo;
          Purchases.isObservationPromotion =
              currentDate.isAfter(observationsFrom) &&
                  currentDate.isBefore(observationsTo.add(Duration(days: 1)));
        }
        if (snapshot.value[firebaseAttributeSearch] != null) {
          var searchFrom = DateTime.parse(
              snapshot.value[firebaseAttributeSearch][firebaseAttributeFrom]);
          var searchTo = DateTime.parse(
              snapshot.value[firebaseAttributeSearch][firebaseAttributeTo]);

          var currentDate = DateTime.now();
          Purchases.searchPromotionFrom = searchFrom;
          Purchases.searchPromotionTo = searchTo;
          Purchases.isSearchPromotion = currentDate.isAfter(searchFrom) &&
              currentDate.isBefore(searchTo.add(Duration(days: 1)));
        }
        if (snapshot.value[firebaseAttributeSearchByPhoto] != null) {
          var searchByPhotoFrom = DateTime.parse(snapshot
              .value[firebaseAttributeSearchByPhoto][firebaseAttributeFrom]);
          var searchByPhotoTo = DateTime.parse(snapshot
              .value[firebaseAttributeSearchByPhoto][firebaseAttributeTo]);

          var currentDate = DateTime.now();
          Purchases.searchByPhotoPromotionFrom = searchByPhotoFrom;
          Purchases.searchByPhotoPromotionTo = searchByPhotoTo;
          Purchases.isSearchByPhotoPromotion =
              currentDate.isAfter(searchByPhotoFrom) &&
                  currentDate.isBefore(searchByPhotoTo.add(Duration(days: 1)));
        }
      }
    });
  }

  Future<void> initStoreInfo() async {
    final bool isAvailable = await InAppPurchaseConnection.instance.isAvailable();
    if (!isAvailable) {
      _iapError();
    }

    final QueryPurchaseDetailsResponse purchaseResponse =
        await InAppPurchaseConnection.instance.queryPastPurchases();
    if (purchaseResponse.error != null) {
      var purchases = await Prefs.getStringListF(keyPurchases, []);
      Purchases.purchases = purchases
          .map((productId) => Purchases.offlineProducts[productId])
          .toList();
    } else {
      Purchases.purchases = [];
      for (PurchaseDetails purchase in purchaseResponse.pastPurchases) {
        if (Platform.isIOS && purchase.status == PurchaseStatus.error) {
          await InAppPurchaseConnection.instance.completePurchase(purchase);
        } else if (await verifyPurchase(purchase)) {
          final pending = Platform.isIOS
              ? purchase.pendingCompletePurchase
              : !purchase.billingClientPurchase.isAcknowledged;

          if (pending) {
            await InAppPurchaseConnection.instance.completePurchase(purchase);
          }
          Purchases.purchases.add(purchase);
        }
      }
      Prefs.setStringList(keyPurchases,
          Purchases.purchases.map((item) => item.productID).toList());
    }

    Offline.initialize();
    _checkPromotions();
    Auth.getCurrentUser();
  }

  @override
  void initState() {
    super.initState();

    Prefs.init();
    Stream purchaseUpdated = InAppPurchaseConnection.instance.purchaseUpdatedStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      _logFailedPurchaseEvent();
      if (mounted) {
        Fluttertoast.showToast(
            msg: S.of(context).product_purchase_failed,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 5);
      }
    });
    _initStoreF = initStoreInfo();

    _localeF = Prefs.getStringF(keyPreferredLanguage).then((String language) {
      var languageCountry = language.split('_');
      return languageCountry.length < 2
          ? null
          : Locale(languageCountry[0], languageCountry[1]);
    });

    Prefs.getStringF(keyRateCount, rateCountInitial.toString()).then((value) {
      if (int.parse(value) < 0) {
        Prefs.getStringF(keyRateState, rateStateInitial).then((value) {
          if (value == rateStateInitial) {
            Prefs.setString(keyRateState, rateStateShould);
          }
        });
      } else {
        Prefs.setString(keyRateCount, (int.parse(value) - 1).toString());
      }
    }).catchError((_) {
      // deal with previous int shared preferences
      Prefs.setString(keyRateCount, rateCountInitial.toString());
    });

    _firebaseCloudMessagingListeners();
  }

  Locale _localeResolutionCallback(
      Locale savedLocale, Locale deviceLocale, Iterable<Locale> supportedLocales) {

    if (savedLocale != null) {
      return savedLocale;
    }

    Locale resultLocale;
    Map<String, Locale> defaultLocale = {};
    for (Locale locale in supportedLocales) {
      if (locale.languageCode == deviceLocale.languageCode &&
          locale.countryCode != null && locale.countryCode == deviceLocale.countryCode) {
        resultLocale = locale;
        break;
      }

      if (locale.languageCode != languageEnglish || locale.countryCode == 'US') {
        defaultLocale[locale.languageCode] = locale;
      }
    }

    if (resultLocale == null) {
      for (Locale locale in supportedLocales) {
        if (locale.languageCode == deviceLocale.languageCode) {
          resultLocale = defaultLocale[locale.languageCode];
          break;
        }
      }
    }

    if (resultLocale == null) {
      resultLocale = defaultLocale[languageEnglish];
    }

    Prefs.setStringList(keyLanguageAndCountry,
        [resultLocale.languageCode, resultLocale.countryCode]);
    return resultLocale;
  }

  @override
  void dispose() {
    Prefs.dispose();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
        future: Future.wait([_localeF, _initStoreF, RemoteConfiguration.setupRemoteConfig()]),
        builder: (BuildContext context, AsyncSnapshot<List<Object>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.done:
              if (snapshot.hasError) {
                FirebaseCrashlytics.instance.log(snapshot.error.toString());
              }
              Map<String, dynamic> notificationData = _notificationData != null
                  ? Map.from(_notificationData)
                  : null;
              _notificationData = null;
              return MaterialApp(
                localeResolutionCallback: (deviceLocale, supportedLocales) {
                  return _localeResolutionCallback(
                      snapshot.data == null ? null : snapshot.data[0], deviceLocale, supportedLocales);
                },
                debugShowCheckedModeBanner: false,
                localizationsDelegates: [
                  S.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  CountryNamesLocalizationsDelegate(),
                ],
                supportedLocales: S.delegate.supportedLocales,
                home: Splash(this.onChangeLanguage, notificationData),
                navigatorObservers: [
                  FirebaseAnalyticsObserver(analytics: _firebaseAnalytics),
                ],
              );
            default:
              return Container(
                decoration: BoxDecoration(color: Colors.white),
                child: Center(
                  child: Image(
                    image: AssetImage('res/images/home.png'),
                  ),
                ),
              );
          }
        });
  }
}
