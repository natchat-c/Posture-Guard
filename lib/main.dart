import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Guard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 173, 226, 250),
        ),
      ),
      home: const MyHomePage(title: 'POSTURE GUARD'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      // ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 35, left: 25, right: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 60,
                    height: 40,
                    child: 
                      FloatingActionButton.extended(
                      onPressed: _incrementCounter,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      icon: const Icon(Icons.monetization_on_rounded),
                      label: Text('$_counter'),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: 
                      FloatingActionButton(
                        onPressed: (){
                          Navigator.push(context, MaterialPageRoute(builder: (context)=>const settings()));
                        },
                        child: Icon(Icons.settings),
                      ),
                  ), 
                ]
              ),
            ),
            const SizedBox(height: 10,),
            const Text('STATUS', style: TextStyle(fontSize: 20),),
            Text('GOOD', style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.green),),
            const SizedBox(height: 20,),
            Image.asset(
              'images/happy slime.png',
              width: 350,
              height: 350,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time_filled, size: 35,),
                const SizedBox(width: 10,),
                Text('$_counter min', style: TextStyle(fontSize: 20),),
                const SizedBox(width: 100,),
                const Icon(Icons.sentiment_dissatisfied_sharp, size: 35,),
                const SizedBox(width: 10,),
                Text('$_counter min', style: TextStyle(fontSize: 20),),
              ],
            ),


            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    height: 60,
                    child: FloatingActionButton(
                      onPressed: _incrementCounter,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      child: Text('CUSTOMIZE', style: TextStyle(fontSize: 25),),
                    ),
                  ),

                  SizedBox(width: 15),

                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      onPressed: _incrementCounter,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      child: const Icon(Icons.equalizer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class settings extends StatelessWidget {

  const settings ({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Padding(
                padding: const EdgeInsets.only(top: 35, left: 20),
                child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Center (child: Text ('Settings', style: TextStyle(fontSize: 50))),
                  SizedBox(height: 30,),
                  const Align(alignment: Alignment.centerLeft,
                  child: Column( 
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alert delay', style: TextStyle(fontSize: 25)),
                      RadioListTile<int>(title: const Text('10 sec'), value: 1, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, visualDensity: const VisualDensity(horizontal: 0, vertical: -4)),
                      RadioListTile<int>(title: const Text('30 sec'), value: 2, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, visualDensity: const VisualDensity(horizontal: 0, vertical: -4)),
                      RadioListTile<int>(title: const Text('1 min'), value: 3, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, visualDensity: const VisualDensity(horizontal: 0, vertical: -4)),
                      RadioListTile<int>(title: const Text('custom'), value: 4, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, visualDensity: const VisualDensity(horizontal: 0, vertical: -4)),
                      //popup custom ui
                      SizedBox(height: 20,),
                      Text('Alert frequency', style: TextStyle(fontSize: 25)),
                      RadioListTile<int>(title: const Text('1 min'), value: 5, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, visualDensity: const VisualDensity(horizontal: 0, vertical: -4)),
                      RadioListTile<int>(title: const Text('5 min'), value: 6, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, visualDensity: const VisualDensity(horizontal: 0, vertical: -4)),
                      RadioListTile<int>(title: const Text('10 min'), value: 7, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, visualDensity: const VisualDensity(horizontal: 0, vertical: -4)),
                      RadioListTile<int>(title: const Text('custom'), value: 8, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, visualDensity: const VisualDensity(horizontal: 0, vertical: -4))
                    ],
                  ),
                  ),
                ],
              ),
            )
          ]
        )
      )
    );
  }
}