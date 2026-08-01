import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';

class Shop extends StatelessWidget {
  const Shop({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const Key('shopScrollView'),
          physics: const ClampingScrollPhysics(),
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
                        Image.asset(
                          'images/happy slime.png',
                          width: 300,
                          height: 300,
                        ),
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
                        context.l10n.buy,
                        style: const TextStyle(fontSize: 25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(
              color: Colors.grey,
              thickness: 5,
              indent: 0,
              endIndent: 0,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
