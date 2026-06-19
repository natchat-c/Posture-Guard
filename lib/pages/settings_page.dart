import 'package:flutter/material.dart';

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
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Alert delay', style: TextStyle(fontSize: 25)),
                        const RadioListTile<int>(
                          title: Text('10 sec'),
                          value: 1,
                          groupValue: 1,
                          onChanged: null,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        const RadioListTile<int>(
                          title: Text('30 sec'),
                          value: 2,
                          groupValue: 1,
                          onChanged: null,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        const RadioListTile<int>(
                          title: Text('1 min'),
                          value: 3,
                          groupValue: 1,
                          onChanged: null,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        const RadioListTile<int>(
                          title: Text('custom'),
                          value: 4,
                          groupValue: 1,
                          onChanged: null,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Alert frequency', style: TextStyle(fontSize: 25)),
                        const RadioListTile<int>(
                          title: Text('1 min'),
                          value: 5,
                          groupValue: 5,
                          onChanged: null,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        const RadioListTile<int>(
                          title: Text('5 min'),
                          value: 6,
                          groupValue: 5,
                          onChanged: null,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        const RadioListTile<int>(
                          title: Text('10 min'),
                          value: 7,
                          groupValue: 5,
                          onChanged: null,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        const RadioListTile<int>(
                          title: Text('custom'),
                          value: 8,
                          groupValue: 5,
                          onChanged: null,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 370,
                          height: 50,
                          child: FloatingActionButton(
                            onPressed: null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Text(
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
