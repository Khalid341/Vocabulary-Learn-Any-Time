import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:english_app/word.dart';
import 'package:english_app/word_list_page.dart';
import 'package:english_app/word_page.dart';
import 'package:english_app/wordservice.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully.");
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  tz.initializeTimeZones();
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final Random _random = Random();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Notification Demo',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark().copyWith(
          primary: const Color(0xFF8DBDFF),
        ),
        useMaterial3: true,
        primaryColor: const Color(0xFF8DBDFF),
        scaffoldBackgroundColor: const Color(0xFF8DBDFF),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(const Color(0xFF374151)),
          ),
        ),
      ),
      home: AnimatedSplashScreen(
        splashIconSize: 5000,
        duration: 3000,
        splash: "assets/logo-no-background.png",
        backgroundColor: const Color(0xFF8DBDFF),
        nextScreen: const NotificationPage(),
      ),
    );
  }
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final WordService wordService = WordService();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late Database _database;
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _initAdMobBanner();
    _configureFirebaseMessaging();
    await initDatabase();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    try {
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (response.payload != null) {
            Map<String, dynamic> data = jsonDecode(response.payload!);
            _handleNotificationTap(data);
          }
        },
      );
      print("Local notifications initialized successfully.");
    } catch (e) {
      print("Error initializing local notifications: $e");
    }
  }

  void _initAdMobBanner() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-2985335779413735/2320113443',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );

    _bannerAd.load();
  }

  @override
  void dispose() {
    super.dispose();
    _bannerAd.dispose();
  }


  Future<List<Word>> getAllWordsFromDatabase() async {
    List<Word> words = [];
    List<Map> result = await _database.query('notifications');
    for (Map wordMap in result) {
      words.add(Word(word: wordMap['word'] as String, meaning: wordMap['meaning'] as String));
    }
    print('Fetched words: ${words.length}');
    return words;
    return words;
  }

  Future<void> saveToDatabase(Map<String, dynamic> payload) async {
    final word = payload['word'];
    final meaning = payload['meaning'];

    print("Received payload: $payload"); // Debug Step 3: Print received payload

    try {
      await _database.insert('notifications', {'word': word, 'meaning': meaning});
      print('Notification saved to database');
    } catch (e) {
      print('Error saving to database: $e'); // Debug Step 5: Catch database errors
    }
  }


  void _configureFirebaseMessaging() {
    _firebaseMessaging.requestPermission(
      sound: true,
      badge: true,
      alert: true,
      provisional: false,
    );
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final payload = message.data;
      _handleNotificationTap(payload);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        final payload = message.data;
        _handleNotificationTap(payload);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification tapped!");
      final payload = message.data;
      print('Notification tap payload: $payload');
      _handleNotificationTap(payload);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final payload = message.data;
      await saveToDatabase(payload);
      _showNotification(payload);
    });
  }

  Future<void> initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'notifications.db');
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
          'CREATE TABLE notifications (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT, meaning TEXT)',
        );
      },
    );

    print('Database initialized');

    // Assign the initialized database to the _database variable
    _database = database;
  }

  Future<void> scheduleNotification(DateTime scheduledDateTime) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'my_notification_channel_id',
      'My Notification Channel',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);

    final List<Word> words = await wordService.getWords();

    if (words.isNotEmpty) {
      final randomWord = words[_random.nextInt(words.length)];
      final payload = {
        'word': randomWord.word,
        'meaning': randomWord.meaning,
        'from_app': true,
      };

      int notificationId = _random.nextInt(100000);  // Generate a random ID for the notification

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,  // Use the random ID
        'Word of the Day',
        'Today\'s word is ${randomWord.word}. Meaning: ${randomWord.meaning}',
        scheduledDate,
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode(payload),
      );
    }
  }

  Future<void> showDateTimePicker(BuildContext context) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime != null) {
        final DateTime scheduledDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        scheduleNotification(scheduledDateTime);

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Notification Scheduled'),
              content: Text(
                  'Notification has been scheduled for $scheduledDateTime'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _showNotification(Map<String, dynamic> payload) async {
    await saveToDatabase(payload);
    final word = payload['word'];
    final meaning = payload['meaning'];

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'my_notification_channel_id', // Replace with your channel ID
      'My Notification Channel', // Replace with your channel name
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Word of the Day',
      'Today\'s word is $word. Meaning: $meaning',
      platformChannelSpecifics,
      payload: jsonEncode({'data': payload}),
    );
  }



  void _handleNotificationTap(Map<String, dynamic> payload) async {
    final word = payload['word'];
    final meaning = payload['meaning'];

    // Save the word and meaning to the SQLite database upon notification tap
    await saveToDatabase(payload);

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => WordPage(
          word: word,
          meaning: meaning,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            // Blue container at the top
            Container(
              height: MediaQuery.of(context).size.height * 0.5, // Let's say you want half of the drawer's height to be blue
              color: const Color(0xFF8DBDFF),

            ),
            // Remaining content with default white background
            Expanded(
              child: ListView(
                // No padding for the ListView
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(
                      color: Color(0xFF8DBDFF),
                      Icons.book,
                    ),
                    title: const Text('Words Page'),
                    onTap: () async {
                      // Retrieve words from the database
                      List<Word> words = await getAllWordsFromDatabase();

                      // Navigate to WordsListPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WordsListPage(words: words),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Vocabulary'),
      ),
      body: Center(
        child: ElevatedButton(

          child: const Text('Set Time To Receive The Word',style: TextStyle()),
          onPressed: () {
            showDateTimePicker(context);
          },
        ),
      ),
      bottomNavigationBar: _isBannerAdReady
          ? SizedBox(
        height: 50,
        child: AdWidget(ad: _bannerAd),
      )
          : const SizedBox.shrink(), // If ad isn't loaded, show nothing

    );

  }
}
