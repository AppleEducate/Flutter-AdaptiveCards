import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("About"),
      ),
      body: ListView(
        padding: EdgeInsets.all(8),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset("assets/neo_logo_light.png"),
                  ),
                  Divider(),
                  Text("Digital Chat Assistance for Business", style: Theme.of(context).textTheme.title,),
                  SizedBox(height: 8,),
                  Text("Neohelden is building a digital chat assistant"
                      "which intigrates into businees system and provides"
                      "a convenient abstraction to all of those systems"
                      "using an easy to use chat interface. \n\n"
                      "Neo has been using AdaptiveCards for a while now and is heavily investing"
                      "into Flutter for the next major release. ", style: Theme.of(context).textTheme.body1,),
                  SizedBox(height: 8,),
                  Align(
                    alignment: Alignment.center,
                    child: OutlineButton(
                      onPressed: () {
                        launch("https://neohelden.com");
                      },
                      child: Text("Check out the website"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Image.asset("assets/norbert.jpg", width: 100,),
                      SizedBox(width: 16,),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Text("Norbert Kozsir - Flutter Developer @Neohelden", style: Theme.of(context).textTheme.title,),
                            SizedBox(height: 8,),
                            Text("Norbert is the lead developer of the Flutter division at Neohelden and "
                                "responsible for this library,"
                                " he is building the Neo App using Flutter for the upcoming release.",
                              style: Theme.of(context).textTheme.body1,),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      OutlineButton(
                        child: Text("Twitter"),
                        onPressed: () {
                          launch("https://twitter.com/norbertkozsir");
                        },
                      ),
                      OutlineButton(
                        child: Text("Medium"),
                        onPressed: () {
                          launch("https://medium.com/@norbertkozsir");
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}
