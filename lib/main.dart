import 'dart:async';
import 'dart:convert';

import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:radio/models/schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String schedule;
  List<String> days = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo'
  ];

  @override
  void initState() {
    super.initState();
    getSchedule();
  }

  void getSchedule() async {
    http.Response res = await http.get(
        'http://app.radiosanadoctrina.cl/json/${days[(DateTime.now().weekday - 1)]}.json');
    setState(() => schedule = utf8.decode(res.bodyBytes));
  }

  @override
  Widget build(BuildContext context) {
    return schedule == null
        ? FlareActor(
            "assets/loading.flr",
            alignment: Alignment.center,
            animation: "Loading_Splash",
          )
        : Platform.isAndroid
            ? MaterialApp(
                title: 'Radio Sana Doctrina',
                theme: ThemeData(
                  fontFamily: 'Roboto',
                  primarySwatch: Colors.green,
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                ),
                home: RadioPage(schedule: schedule, getSchedule: getSchedule),
              )
            : CupertinoApp(
                title: 'Radio Sana Doctrina',
                home: RadioPage(schedule: schedule, getSchedule: getSchedule),
              );
  }
}

class RadioPage extends StatefulWidget {
  final String schedule;
  final Function getSchedule;
  RadioPage({Key key, this.schedule, this.getSchedule}) : super(key: key);

  @override
  _RadioPageState createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  AudioPlayer player;
  List<Schedule> schedule;
  bool playing = false;
  bool transition = false;
  bool stripesFlag = true;
  bool loading = true;
  Timer interval;
  Color green = Color.fromRGBO(0, 162, 90, 1.0);
  Color grey = Color.fromRGBO(100, 104, 109, 1.0);
  Color darkGrey = Color.fromRGBO(79, 83, 86, 1.0);

  @override
  void initState() {
    super.initState();

    // Schedule
    schedule = _getSchedule();

    // Stream Player
    player = AudioPlayer();
    player.setUrl('http://162.210.196.142:8124/stream').catchError((error) {
      print(error);
    }).then((value) => setState(() => loading = false));

    // Timer Periodic
    interval = Timer.periodic(Duration(minutes: 1), (Timer timer) async {
      if (schedule.length == 1 &&
          DateTime.now().isAfter(DateTime(schedule[0].date.year,
                  schedule[0].date.month, schedule[0].date.day)
              .add(Duration(days: 1)))) {
        print('getting new schedule');
        widget.getSchedule();
      }
      List<Schedule> newSchedule = _reorderList(schedule);
      if (newSchedule.length != schedule.length) {
        setState(() => transition = true);
        await Future.delayed(Duration(seconds: 1));
      }
      setState(() {
        schedule = newSchedule;
        stripesFlag = transition ? !stripesFlag : stripesFlag;
        transition = false;
      });
    });
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      schedule = _getSchedule();
    });
  }

  @override
  void dispose() {
    interval.cancel();
    player.dispose();
    super.dispose();
  }

  List<Schedule> _getSchedule() {
    List<Schedule> aux = [];
    for (dynamic schedule in jsonDecode(widget.schedule)['schedule']) {
      aux.add(
        Schedule(
          lecture: schedule['lecture'],
          preacher: schedule['preacher'],
          date: DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            schedule['hour'],
            schedule['minute'],
          ),
        ),
      );
    }

    return _reorderList(aux);
  }

  List<Schedule> _reorderList(List<Schedule> list) {
    List<Schedule> aux = [];
    for (int i = 0; i < list.length; ++i) {
      if (i == list.length - 1) {
        aux.add(list[i]);
      } else if (list[i + 1].date.isAfter(DateTime.now())) {
        aux.add(list[i]);
      }
    }
    return aux;
  }

  List<Schedule> _listToShow(List<Schedule> list) {
    List<Schedule> aux = [];
    if (list.length > 1) {
      aux = list.getRange(1, list.length).toList();
    }

    return aux;
  }

  void _play() {
    setState(() {
      playing = true;
    });
    player = AudioPlayer();
    player.setUrl('http://162.210.196.142:8124/stream').catchError((error) {
      print(error);
    }).then((value) {
      player.play();
    });
  }

  void _stop() {
    player.pause();
    setState(() {
      playing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget lectureBuilder(schedule) {
      return schedule.preacher == null
          ? Text(
              schedule.lecture,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                color: green,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            )
          : RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: schedule.lecture,
                    style: TextStyle(
                      color: green,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  TextSpan(
                    text: '\n${schedule.preacher}',
                    style: TextStyle(
                      color: green,
                      fontWeight: FontWeight.w300,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        child: ListView(
          children: [
            Container(
              height: 90,
              child: Center(
                child: Transform.scale(
                  scale: 1.8,
                  child: ClipRect(
                    child: Container(
                      child: Align(
                        alignment: Alignment.center,
                        heightFactor: 0.7,
                        widthFactor: 0.7,
                        child: Image.asset('assets/logo.jpeg'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              color: green,
              padding: EdgeInsets.all(7.0),
              child: Text(
                'Ahora transmitiendo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                  fontSize: 20,
                ),
              ),
            ),
            Container(
              color: Colors.black,
              height: 80,
              margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Row(
                children: <Widget>[
                  Flexible(
                    fit: FlexFit.tight,
                    flex: 1,
                    child: loading
                        ? Transform.scale(
                            scale: 1.7,
                            child: Container(
                              alignment: Alignment.center,
                              child: FlareActor(
                                "assets/loading.flr",
                                alignment: Alignment.center,
                                animation: "Loading",
                              ),
                            ),
                          )
                        : FlatButton(
                            onPressed: playing ? _stop : _play,
                            child: Transform.scale(
                              scale: 1.5,
                              child: Container(
                                padding: EdgeInsets.all(15.0),
                                child: Image.asset(
                                  playing
                                      ? 'assets/pause.png'
                                      : 'assets/play.png',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                  Flexible(
                    fit: FlexFit.tight,
                    flex: 2,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        AnimatedContainer(
                          duration:
                              Duration(milliseconds: transition ? 500 : 0),
                          curve: Curves.easeInOut,
                          transform: Matrix4.translationValues(
                              0.0, transition ? -50.0 : 0.0, 0.0),
                          child: AnimatedOpacity(
                            opacity: transition ? 0.0 : 1.0,
                            duration:
                                Duration(milliseconds: transition ? 500 : 0),
                            child: lectureBuilder(schedule[0]),
                          ),
                        ),
                        schedule.length == 1
                            ? Container()
                            : AnimatedContainer(
                                duration: Duration(
                                    milliseconds: transition ? 500 : 0),
                                curve: Curves.easeInOut,
                                transform: Matrix4.translationValues(
                                    0.0, transition ? 0.0 : 50.0, 0.0),
                                child: AnimatedOpacity(
                                  opacity: transition ? 1.0 : 0.0,
                                  duration: Duration(
                                      milliseconds: transition ? 500 : 0),
                                  child: lectureBuilder(schedule[1]),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: green,
              padding: EdgeInsets.all(7.0),
              child: Text(
                'A continuación',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                  fontSize: 20,
                ),
              ),
            ),
            Container(
              child: ClipRect(
                child: Align(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: transition ? 500 : 0),
                    curve: Curves.easeInOut,
                    transform: Matrix4.translationValues(
                        0.0, transition ? -36.0 : 0.0, 0.0),
                    child: Column(
                      children: _listToShow(schedule)
                          .map(
                            (e) => Container(
                              margin: EdgeInsets.symmetric(horizontal: 40.0),
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              color: schedule.indexOf(e) % 2 ==
                                      (stripesFlag ? 0 : 1)
                                  ? grey
                                  : darkGrey,
                              child: Row(
                                children: <Widget>[
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Text(
                                      '${e.date.hour < 10 ? '0' : ''}${e.date.hour}:00',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    flex: 1,
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: Text(
                                      e.lecture,
                                      textAlign: TextAlign.left,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    flex: 2,
                                  )
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
