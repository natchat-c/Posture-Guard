import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String display = '0';
  String firstNumber = '';
  String operation = '';
  String displayText = '0';

  void pressNumber(String number) {
    setState(() {
      if (display == '0') {
        display = number;
      } else {
        display += number;
      }
      if (operation == '') {
        displayText = display;
      } else {
        displayText = firstNumber + operation + display;
      }
    });
  }
  void pressOperator(String op) {
    if (operation == ''){
      setState(() {
        firstNumber = display;
        operation = op;
        displayText = firstNumber + op;
        display = '0';
      });
    }
  }
  void calculateResult() {
    setState(() {
      double num1 = double.parse(firstNumber);
      double num2 = double.parse(display);
      double result = 0;

      if (operation == '+') {
        result = num1 + num2;
      }
      else if (operation == '-') {
        result = num1 - num2;
      }
      else if (operation == 'x') {
        result = num1 * num2;
      }
      else if (operation == '÷') {
        result = num1 / num2;
      }
      displayText = result.toString();
      setState(() {
        firstNumber = '';
        operation = '';
        display = '0';
      });
    });
  }
  void clearAll(){
    setState(() {
    display = '0';
    firstNumber = '';
    operation = '';
    displayText = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              displayText,
              style: Theme.of(context).textTheme.headlineMedium,
            )
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top:100),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: () => pressNumber('1'),
                  tooltip: 'Increment',
                  child: Text('1'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressNumber('2'),
                  tooltip: 'Increment',
                  child: Text('2'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressNumber('3'),
                  tooltip: 'Increment',
                  child: Text('3'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressOperator('+'),
                  tooltip: 'Increment',
                  child: Text('+'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                )
              ],
            ),
            const SizedBox(height: 30,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: () => pressNumber('4'),
                  tooltip: 'Increment',
                  child: Text('4'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressNumber('5'),
                  tooltip: 'Increment',
                  child: Text('5'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressNumber('6'),
                  tooltip: 'Increment',
                  child: Text('6'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressOperator('-'),
                  tooltip: 'Increment',
                  child: Text('-'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                )
              ],
            ),
            const SizedBox(height: 30,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: () => pressNumber('7'),
                  tooltip: 'Increment',
                  child: Text('7'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressNumber('8'),
                  tooltip: 'Increment',
                  child: Text('8'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressNumber('9'),
                  tooltip: 'Increment',
                  child: Text('9'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressOperator('x'),
                  tooltip: 'Increment',
                  child: Text('x'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                )
              ],
            ),  
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: clearAll,
                  tooltip: 'Increment',
                  child: Text('c'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressNumber('0'),
                  tooltip: 'Increment',
                  child: Text('0'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: calculateResult,
                  tooltip: 'Increment',
                  child: Text('='),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                ),
                const SizedBox(width: 30,),
                FloatingActionButton(
                  onPressed: () => pressOperator('÷'),
                  tooltip: 'Increment',
                  child: Text('÷'),
                  backgroundColor: Colors.white,
                  hoverColor: Colors.grey,
                )
              ],
            ),  
          ],
        ),
      ),
    );   // This trailing comma makes auto-formatting nicer for build methods.
  }
}
