import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:treebook/widgets/auth.dart';
import 'package:treebook/widgets/basics.dart';
import '../models.dart' show Book, Page_;
import '../client.dart' show ApiClient;
import '../exceptions.dart';


class PagePage extends StatefulWidget {
  const PagePage({super.key, required this.initialPageId, required this.book});

  final String initialPageId;
  final Book book;

  @override
  State<PagePage> createState() => _PagePageState();
}

class _PagePageState extends State<PagePage> {

  late String _pageId;
  late Future<Page_> _future;

  @override
  void initState() {
    super.initState();
    _pageId = widget.initialPageId;
    _future = Provider.of<ApiClient>(context, listen: false).fetchPage(_pageId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        leading: IconButton(
          onPressed: () { Navigator.pop(context); }, 
          icon: const Icon(Icons.arrow_back)
        ),
        actions: [
          FutureBuilder(
            future: _future, 
            builder:(context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && !snapshot.data!.last) {
                return Consumer<ApiClient>(
                  builder:(context, client, child) => FilledButton(
                    onPressed: () {
                      if (client.anonymous) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => LoginPage(
                              onSuccess: () { 
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => PageFormPage(prevPageId: _pageId),
                                  )
                                ).then((value) {
                                  setState(() {
                                    _pageId = value;
                                    _future = Provider.of<ApiClient>(context, listen: false).fetchPage(_pageId);
                                  });
                                });
                              }
                            ),
                          )
                        );
                      }
                      else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PageFormPage(prevPageId: _pageId),
                          )
                        ).then((value) {
                          setState(() {
                            _pageId = value;
                            _future = Provider.of<ApiClient>(context, listen: false).fetchPage(_pageId);
                          });
                        });
                      }
                    },
                    child: const Text("Make a branch"),
                  )
                );
              }
              return Text("");
            },
          ),
          const SizedBox(width: 32)
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder:(context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Text("Error: ${snapshot.error}");
            } else {
              final Page_ page = snapshot.data!;
              return Row(
                children: [
                  Flexible(
                    flex: 3,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: IconButton(
                              onPressed: () => setState(() {
                                if (!page.first) {
                                  _pageId = page.prevPageId!;
                                  _future = Provider.of<ApiClient>(context, listen: false).fetchPage(_pageId);
                                }
                              }),
                              icon: Icon(
                                Icons.arrow_back_ios
                              )
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(right: 12),
                              child: TextWithIndent(
                                data: page.text,
                                indent: 32,
                                textAlign: TextAlign.justify,
                              )
                            )
                          )
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    child: FutureBuilder(
                      future: Provider.of<ApiClient>(context, listen: false).fetchPages({'next_for_f': page.id}, 'likes_count', true, 0, 10),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          if (snapshot.hasError) {
                            return Text("Error: ${snapshot.error}");
                          } else {
                            final List<Page_> pages = snapshot.data!;
                            return ListView.builder(
                              itemCount: pages.length,
                              itemBuilder: (context, index) {
                                return PageListItem(
                                  page: pages[index],
                                  onTap: () {
                                    setState(() {
                                      _pageId = pages[index].id;
                                      _future = Provider.of<ApiClient>(context, listen: false).fetchPage(_pageId);
                                    });
                                  },
                                );
                              },
                            );
                          }
                        } else {
                          return Center(child: CircularProgressIndicator());
                        }
                      },
                    )
                  )
                ],
              );
            }
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      )
    );
  }
}

class PageListItem extends StatelessWidget {
  const PageListItem({super.key, required this.page, this.onTap});

  final Page_ page;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ListTile(
        title: Text('${page.text.substring(0, min(page.text.length, 40)).replaceAll('\n', ' ').trim()}...'),
        subtitle: Text(page.author.username),
      )
    );
  }
}

class PageForm extends StatefulWidget {
  const PageForm({super.key, required this.prevPageId, this.onCancelled, this.onSuccess});

  final String prevPageId;
  final VoidCallback? onCancelled;
  final Function(String pageId)? onSuccess;

  @override
  State<PageForm> createState() => _PageFormState();
}

class _PageFormState extends State<PageForm> { 

  late TextEditingController _textController;
  bool _last = false;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  void _submit() {
    setState(() {
      _error = null;
      _processing = true;
    });
    Provider.of<ApiClient>(context, listen: false).postPage(widget.prevPageId, _textController.text, _last).then(
      (pageId) {
        setState(() {
          _processing = false;
        });
        widget.onSuccess?.call(pageId);
      },
      onError: (e) {
        String error;
        switch (e) {
          case AuthorizationRequiredException _:
            error = "You must be logged in to create a page.";
          case InvalidPageTextException _:
            error = "Text must be at most 2500 characters.";
          case PageNotFoundException _:
            error = "The page you are trying to make a branch from does not exist.";
          case LastPageException _:
            error = "The page you are trying to make a branch from marked as 'last'";
          default:
            error = "An unexpected error occurred";
        }
        setState(() {
          _processing = false;
          _error = error;
        });
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return _processing ? Center(child: CircularProgressIndicator()) : Form(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Checkbox(
                  value: _last, 
                  onChanged: (val) => setState(() {
                    _last = val!;
                  }),
                  semanticLabel: "Last page",
                ),
                Text("Last page", style: Theme.of(context).textTheme.labelLarge,),
                Text(
                  _error ?? "",
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: TextFormField(
                controller: _textController,
                maxLines: null,
                expands: true,
                strutStyle: null,
                maxLength: 2500,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                  border: InputBorder.none,
                ),
              )
            )
          ),
          SizedBox(
            width: 256,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: widget.onCancelled, 
                  child: Text("Cancel")
                ),
                FilledButton(
                  onPressed: _submit, 
                  child: Text("Submit")
                )
              ],
            )
          ),
          SizedBox(height: 32)
        ],
      ),
    );
  }
}

class PageFormPage extends StatelessWidget {
  const PageFormPage({super.key, required this.prevPageId});

  final String prevPageId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Writing"),
        leading: IconButton(
          onPressed: () { Navigator.pop(context); }, 
          icon: const Icon(Icons.arrow_back)
        ),
      ),
      body: PageForm(
        prevPageId: prevPageId,
        onCancelled: () { Navigator.pop(context); },
        onSuccess: (pageId) { Navigator.pop(context, pageId); }
      )
    );
  }
}