import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
            Padding(
              padding: const EdgeInsets.only(top: 35, left: 25, right: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 60,
                    height: 40,
                    child: FloatingActionButton.extended(
                      onPressed: _incrementCounter,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      icon: const Icon(Icons.monetization_on_rounded),
                      label: Text('$_counter'),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const settings(),
                          ),
                        );
                      },
                      child: Icon(Icons.settings),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text('STATUS', style: TextStyle(fontSize: 20)),
            Text(
              'GOOD',
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            Image.asset('images/happy slime.png', width: 350, height: 350),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time_filled, size: 35),
                const SizedBox(width: 10),
                Text('$_counter min', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 100),
                const Icon(Icons.sentiment_dissatisfied_sharp, size: 35),
                const SizedBox(width: 10),
                Text('$_counter min', style: TextStyle(fontSize: 20)),
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const customizes(),
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text('CUSTOMIZE', style: TextStyle(fontSize: 25)),
                    ),
                  ),

                  SizedBox(width: 15),

                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Statistics(),
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
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
  const settings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 35, left: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(
                          child: Text(
                            'Settings',
                            style: TextStyle(fontSize: 50),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: FloatingActionButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Icon(Icons.arrow_back),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alert delay', style: TextStyle(fontSize: 25)),
                        RadioListTile<int>(
                          title: const Text('10 sec'),
                          value: 1,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        RadioListTile<int>(
                          title: const Text('30 sec'),
                          value: 2,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        RadioListTile<int>(
                          title: const Text('1 min'),
                          value: 3,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        RadioListTile<int>(
                          title: const Text('custom'),
                          value: 4,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        //popup custom ui
                        SizedBox(height: 20),
                        Text('Alert frequency', style: TextStyle(fontSize: 25)),
                        RadioListTile<int>(
                          title: const Text('1 min'),
                          value: 5,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        RadioListTile<int>(
                          title: const Text('5 min'),
                          value: 6,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        RadioListTile<int>(
                          title: const Text('10 min'),
                          value: 7,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        RadioListTile<int>(
                          title: const Text('custom'),
                          value: 8,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          width: 370,
                          height: 50,
                          child: FloatingActionButton(
                            onPressed: null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Text(
                              'Disable',
                              style: TextStyle(fontSize: 25),
                            ),
                          ),
                        ),
                      ],
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

class Statistics extends StatefulWidget {
  const Statistics({super.key});

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  int usage = 0;

  void stat() {
    setState(() {
      usage++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 35, left: 20, right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(
                          child: Text(
                            'Statistics',
                            style: TextStyle(fontSize: 50),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: FloatingActionButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Icon(Icons.arrow_back),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today', style: TextStyle(fontSize: 25)),
                        SizedBox(height: 20),
                        Text(
                          'Daily Usage: $usage min',
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          'Good posture: $usage min',
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          'Bad posture: $usage min',
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          'Score: $usage',
                          style: const TextStyle(fontSize: 20),
                        ),
                        SizedBox(height: 20),
                        const Text('This week', style: TextStyle(fontSize: 25)),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('S'),
                                SizedBox(height: 5),
                                Text('73'),
                              ],
                            ),

                            Column(
                              children: [
                                Text('M'),
                                SizedBox(height: 5),
                                Text('95'),
                              ],
                            ),

                            Column(
                              children: [
                                Text('T'),
                                SizedBox(height: 5),
                                Text('62'),
                              ],
                            ),

                            Column(
                              children: [
                                Text('W'),
                                SizedBox(height: 5),
                                Text('72'),
                              ],
                            ),

                            Column(
                              children: [
                                Text('TH'),
                                SizedBox(height: 5),
                                Text('69'),
                              ],
                            ),

                            Column(
                              children: [
                                Text('F'),
                                SizedBox(height: 5),
                                Text('70'),
                              ],
                            ),

                            Column(
                              children: [
                                Text('SA'),
                                SizedBox(height: 5),
                                Text('87'),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 40,),
                        SizedBox(
                          height: 200,
                          width: 360,

                          child: 
                          LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 100,
                              titlesData: FlTitlesData(show: true, 
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                              reservedSize: 20,
                              interval: 1,
                              getTitlesWidget: (double value, TitleMeta meta){
                                switch(value.toInt()){
                                  case 0: return const Text('S');
                                  case 1: return const Text('M');
                                  case 2: return const Text('T');
                                  case 3: return const Text('W');
                                  case 4: return const Text('TH');
                                  case 5: return const Text('F');
                                  case 6: return const Text('SA');
                                  default: return const Text('');
                                }
                              }                            
                              )),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    FlSpot(0, 30),
                                    FlSpot(1, 60),
                                    FlSpot(2, 50),
                                    FlSpot(3, 30),
                                    FlSpot(4, 60),
                                    FlSpot(5, 50),
                                    FlSpot(6, 30),
                                  ],
                                  isCurved: false,
                                  color: Colors.black,
                                  barWidth: 4,
                                  dotData: FlDotData(show: true)                             
                                ),
                              ],
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: true, border: Border.all(color: Colors.black)),    
                            ),
                          ),
                        ),
                      ],
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

class customizes extends StatelessWidget {
  const customizes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 45, left: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 270,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset('images/happy slime.png', width: 300, height: 300),
                        Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: FloatingActionButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Icon(Icons.arrow_back),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey, thickness: 5, indent: 0, endIndent: 0,),
            SizedBox(height: 20,),
            Padding(
              padding: const EdgeInsets.only(bottom: 30, left: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    height: 50,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const shop(),
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                      'Buy more',
                      style: TextStyle(fontSize: 25),
                      ),
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

class shop extends StatelessWidget {
  const shop ({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 45, left: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 270,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset('images/happy slime.png', width: 300, height: 300),
                        Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: FloatingActionButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Icon(Icons.arrow_back),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    height: 50,
                    child: FloatingActionButton(
                      onPressed: null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                      'Buy',
                      style: TextStyle(fontSize: 25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20,),
            Divider(color: Colors.grey, thickness: 5, indent: 0, endIndent: 0,),
            SizedBox(height: 20,),
          ],
        ),
      ),
    );
  }
}