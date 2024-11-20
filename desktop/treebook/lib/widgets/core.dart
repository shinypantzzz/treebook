import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../client.dart' show ApiClient;
import 'auth.dart' show LoginPage;
import 'book.dart' show BookGrid, BookForm;
import '../genres.dart';


class TreeBookApp extends StatelessWidget {
  const TreeBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ApiClient(),
      child: ChangeNotifierProvider(
        create: (context) => Genres(Provider.of<ApiClient>(context, listen: false)),
        child: MaterialApp(
          title: 'Tree Book',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: const HomePage(),
        )
      )
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State <HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiClient>(
      builder: (context, client, child) => Scaffold(
        appBar: ClientAppBar(title: "TreeBook"),
        body: BookGrid(),
        floatingActionButton: client.anonymous ? null : IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => Material(
                  child: BookForm()
                )
              )
            );
          }, 
          icon: const Icon(
            Icons.add_circle_outline,
            size: 100,
          )
        ),
      )
    );
  }
}

class ClientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ClientAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => AppBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiClient>(
      builder:(context, client, child) {
        final actions = <Widget>[];
        if (client.anonymous) {
          actions.add(
            TextButton(
              child: const Text("Log in"), 
              onPressed: () => {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LoginPage()
                  )
                )
              }
            )
          );
        } else {
          actions.addAll(
            [
              Text(client.username!),
              const SizedBox(width: 16),
              TextButton(
                onPressed: client.disconnect,
                child: const Text("Log out"),
              )
            ]
          );
        }
        actions.add(const SizedBox(width: 32));
        return AppBar(
          title: Text(title),
          actions: actions
        );
      },
    );
  }
}