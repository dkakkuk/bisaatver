import 'dart:io';

import 'package:after_layout/after_layout.dart';
import 'package:cool_alert/cool_alert.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:platform_device_id/platform_device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_connection_checker/simple_connection_checker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';

String _myToken = "";
String _deviceId = "";
String _locationData = "";

const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    importance: Importance.high,
    playSound: true
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    var position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _locationData = "${position.latitude},${position.longitude}";
    print("START: $_locationData");
    return await Geolocator.getCurrentPosition();
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  await Permission.storage.request();
  await Permission.photos.request();
  await Permission.camera.request();
  await Permission.photosAddOnly.request();
  await Permission.mediaLibrary.request();
  await Permission.location.request();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(false);

    var swAvailable = await AndroidWebViewFeature.isFeatureSupported(
        AndroidWebViewFeature.SERVICE_WORKER_BASIC_USAGE);
    var swInterceptAvailable = await AndroidWebViewFeature.isFeatureSupported(
        AndroidWebViewFeature.SERVICE_WORKER_SHOULD_INTERCEPT_REQUEST);

    if (swAvailable && swInterceptAvailable) {
      AndroidServiceWorkerController serviceWorkerController = AndroidServiceWorkerController.instance();

      serviceWorkerController.serviceWorkerClient = AndroidServiceWorkerClient(
        shouldInterceptRequest: (request) async {
          //print(request);
          return null;
        },
      );
    }
  }

  _determinePosition();
  _deviceId = (await PlatformDeviceId.getDeviceId)!;
  _myToken = (await FirebaseMessaging.instance.getToken())!;

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarBrightness: Brightness.light,
    ));

    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Bisaatver',
        theme: ThemeData(
          primarySwatch: Colors.deepOrange,
        ),
        home: AnaSayfa()
    );
  }
}


class AnaSayfa extends StatefulWidget {
  const AnaSayfa({Key? key}) : super(key: key);

  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  Future _checkInternet() async {
    bool connectivityResult =
    await SimpleConnectionChecker.isConnectedToInternet();
    if (connectivityResult == true) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Splash()));
    }
  }

  @override
  void initState() {
    super.initState();
    _checkInternet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.all(30.0),
            child: Center(
                child: Text(
                  "Lütfen internet bağlantınızı kontrol ediniz.",
                  textAlign: TextAlign.center,
                )),
          ),
          const Icon(Icons.wifi_off, size: 44),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () {
                _checkInternet();
              },
              child: const Text("Tekrar dene"))
        ],
      ),
    );
  }
}


class Splash extends StatefulWidget {
  @override
  _SplashState createState() => _SplashState();
}

class _SplashState extends State<Splash> with AfterLayoutMixin<Splash> {

  Future checkFirstSeen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool _seen = (prefs.getBool('slider') ?? false);
    if (Platform.isAndroid) {
      if (_seen) {
        Navigator.of(context).pushReplacement(new MaterialPageRoute(builder: (context) => new HomePage()));
      }else{
        CoolAlert.show(
            context: context,
            type: CoolAlertType.info,
            confirmBtnText: "Devam",
            onConfirmBtnTap: () {
              Navigator.of(context).pushReplacement(new MaterialPageRoute(builder: (context) => new HomePage()));
            },
            title: "Bisaatver",
            text: "Konumunuz, aktivite alanları takip etmek için kullanılacaktır."
        );
      }
    }else if(Platform.isIOS) {
      Navigator.of(context).pushReplacement(new MaterialPageRoute(builder: (context) => new HomePage()));
    }
    await prefs.setBool('slider', true);
  }


  @override
  void afterFirstLayout(BuildContext context) {
    checkFirstSeen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
          child: Image(image: AssetImage("assets/logo.png"), width: 200,)
      ),
    );
  }
}


//HomePage
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late HeadlessInAppWebView headlessWebView;

  bool _isLoading = false;
  String phone = "android";
  String finalUrl = "";


  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? _controller;
  late PullToRefreshController pullToRefreshController;


  @override
  void initState() {
    super.initState();

    setState(() {});

    if (Platform.isAndroid) {
      phone = "android";
    }else if(Platform.isIOS) {
      phone = "ios";
    }
    _requestPermission();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                color: Colors.red[900],
                playSound: true,
                icon: '@mipmap/ic_launcher',
              ),
            ));
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        showDialog(
            context: context,
            builder: (_) {
              return AlertDialog(
                title: Text(notification.title.toString()),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(notification.body.toString())],
                  ),
                ),
              );
            });
      }
    });

    finalUrl = "$mainUrl/$phone/$_deviceId/$_myToken/$_locationData";

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.grey,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          _controller?.reload();
        } else if (Platform.isIOS) {
          _controller?.loadUrl(
              urlRequest: URLRequest(url: await _controller?.getUrl()));
        }
      },
    );
  }

  @override
  void dispose() {
    headlessWebView.dispose();
    super.dispose();
  }

  void _requestPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }

  }

  void _launchURL(String url) async => await canLaunch(url) ? await launch(url) : throw 'Could not launch $url';

  Future<bool> _onWillPop(context) async {
    if (_controller?.canGoBack != null) {
      _controller?.goBack();
      return false;
    }else{
      SystemNavigator.pop();
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {

    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        body:  SafeArea(
            child: LoadingOverlay(
              isLoading: _isLoading,
              // demo of some additional parameters
              opacity: 1,
              progressIndicator: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ClipOval(
                          child: Image.asset("assets/logo.png",
                            height: 48,
                            width: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        child: Container(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 1,
                          ),
                        ),
                      )
                    ],
                  ),

                  SizedBox(height: 20),
                  Text("Yükleniyor...", style: TextStyle(color: Colors.white))
                ],
              ),

              child: InAppWebView(
                key: webViewKey,
                initialUrlRequest: URLRequest(url: Uri.parse(finalUrl)),
                pullToRefreshController: pullToRefreshController,
                initialOptions: InAppWebViewGroupOptions(
                    crossPlatform: InAppWebViewOptions(
                      mediaPlaybackRequiresUserGesture: false,
                    ),
                    android: AndroidInAppWebViewOptions(
                        useHybridComposition: true,
                        allowContentAccess: true
                    ),
                    ios: IOSInAppWebViewOptions(
                      allowsInlineMediaPlayback: true,
                    )
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                },

                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  var uri = navigationAction.request.url!;
                  if (uri.toString().startsWith('tel:')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().endsWith('.pdf') || uri.toString().endsWith('.xls') || uri.toString().endsWith('.xlsx') || uri.toString().endsWith('.doc') || uri.toString().endsWith('.docx')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().startsWith('mailto:')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().startsWith('sms:')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().startsWith('https://wa.me/')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().startsWith('https://twitter.com/')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().startsWith('https://www.facebook.com/')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().startsWith('https://www.linkedin.com/')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().startsWith('https://www.youtube.com/')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().startsWith('https://www.instagram.com/')) {
                    _launchURL(uri.toString());
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },

                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;
                  });
                },

                onLoadStop: (controller, url) async {
                  pullToRefreshController.endRefreshing();
                  setState(() {
                    print(url);
                    _isLoading = false;
                  });
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) {
                    pullToRefreshController.endRefreshing();
                  }
                },
                onLoadHttpError: (controller, url, statusCode, description) {
                  pullToRefreshController.endRefreshing();
                  _controller?.loadUrl(
                      urlRequest: URLRequest(
                          url: Uri.parse(finalUrl)));
                },
                onLoadError: (controller, url, statusCode, description) {
                  pullToRefreshController.endRefreshing();
                  _controller?.loadUrl(
                      urlRequest: URLRequest(
                          url: Uri.parse(finalUrl)));
                },
                androidOnPermissionRequest: (controller, origin, resources) async {
                  return PermissionRequestResponse(
                      resources: resources,
                      action: PermissionRequestResponseAction.GRANT);
                },
              ),

            )
        ),
      ),
    );
  }
}