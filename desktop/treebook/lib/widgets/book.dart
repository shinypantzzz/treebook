import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:treebook/genres.dart';

import '../models.dart' show Book, Genre;
import '../config.dart' show API_BASE_URL, API_PORT, API_STATIC_PATH;
import '../client.dart' show ApiClient;
import 'basics.dart';
import 'page.dart';


class BookGridItem extends StatefulWidget {
  const BookGridItem({super.key, required this.book});

  final Book book;

  @override
  State<BookGridItem> createState() => _BookGridItemState();

}

class _BookGridItemState extends State<BookGridItem> {

  double _elevation = 10;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      hoverColor: const Color.fromARGB(0, 0, 0, 0),
      onTap:() {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => BookPage(book: widget.book)));
      },
      onHover: (on) {
        setState(() {
          _elevation = on ? 20 : 10;
        });
      },
      child: Card(
        elevation: _elevation,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: widget.book.imagePath == null ? Center(child: Icon(Icons.image)) : Image.network(
                  'http://$API_BASE_URL:$API_PORT/$API_STATIC_PATH/${widget.book.imagePath}',
                  frameBuilder: (context, child, frame, loaded) => Center(child: child),
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.book.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      'Author: ${widget.book.author.username}',
                      style: Theme.of(context).textTheme.labelMedium,
                      textAlign: TextAlign.right,
                    )
                  ],
                )
              )
            ],
          ),
        )
      )
    );
  }
}

class BookGrid extends StatefulWidget {
  const BookGrid({super.key});

  @override
  State<BookGrid> createState() => _BookGridState();

}

class _BookGridState extends State<BookGrid> {

  final List<Book> _books = [];
  final Map<String, String> _filters = {};
  String _orderBy = 'likes_count';
  bool _desc = true;
  int _offset = 0;
  final int _limit = 20;
  bool _loading = false;

  void _loadMoreBooks(ApiClient client) {
    setState(() {
      _loading = true;
    });
    client.fetchBooks(_filters, _orderBy, _desc, _offset, _limit).then(
      (books) {
        setState(() {
          _books.addAll(books);
          _offset += books.length;
          _loading = false;
        });
      }, 
      onError: (e) {

      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadMoreBooks(Provider.of<ApiClient>(context, listen: false));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiClient>(
      builder: (context, client, child) {
        return NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            if (notification.metrics.atEdge) {
              if (!_loading) {
                _loadMoreBooks(client);
              }
            }
            return false;
          },
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 2),
            itemBuilder:(context, index) => index < _books.length ? BookGridItem(book: _books[index]) : const Card(),
            itemCount: _books.length + (_loading ? _limit : 0),
          )
        );
      }
    );
  }
}

class BookPage extends StatelessWidget {
  const BookPage({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        leading: IconButton(
          onPressed: () { Navigator.pop(context); }, 
          icon: const Icon(Icons.arrow_back)
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => PagePage(initialPageId: book.firstPageId, book: book))
              );
            },
            child: const Text("Start reading"),
          ),
          const SizedBox(width: 32)
        ],
      ),
      body: Row(
        children: [
          Flexible(
            child: book.imagePath == null ? Center(child: Icon(Icons.image)) : Image.network(
              'http://$API_BASE_URL:$API_PORT/$API_STATIC_PATH/${book.imagePath}',
              loadingBuilder: (context, child, loadingProgress) => Padding(padding: const EdgeInsets.all(32), child: child),
            ),
          ),
          Flexible(
            fit: FlexFit.tight,
            child: Padding(
              padding: const EdgeInsets.all(32), 
              child:  Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Author: ${book.author.username}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Genre: ${book.genre?.name ?? 'unknown'}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              )
            )
          )
        ],
      ),
    );
  }
}

class BookForm extends StatefulWidget {
  const BookForm({super.key});

  @override
  State<BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<BookForm> {

  bool _processing = false;
  late TextEditingController _titleController;
  late TextEditingController _textController;
  Genre? _genre;
  String? _filePath; 
  final GlobalKey _formKey = GlobalKey<FormState>();
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _textController = TextEditingController();
  }

  void _send() {
    setState(() {
      _processing = true;
    });
    Provider.of<ApiClient>(context, listen: false).postBook(
      title: _titleController.text,
      text: _textController.text,
      coverPath: _filePath,
      genreId: _genre?.id,
    ).then((resp) {
      setState(() {
        _processing = false;
        _error = null;
      });
      if (!context.mounted) {
         return; 
      }
      Navigator.pop(context);
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => FutureBuilder(
            future: Provider.of<ApiClient>(context, listen: false).fetchBook(resp['book_id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Material(child: Center(child: CircularProgressIndicator()));
              } else if (snapshot.connectionState == ConnectionState.done) {
                if (!snapshot.hasError) {
                  return BookPage(book: snapshot.data!);
                }
                return Text("Error fetching book");
              } else {
                return Text("");
              }
            },
          )
        )
      );
    }, 
    onError: (error) {
      setState(() {
        _processing = false;
        _error = error.toString();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _processing ? CircularProgressIndicator() : Form(
          key: _formKey,
          child: Padding(padding: EdgeInsets.all(16), child: Column(
            children: [
              Text(_error?? ""),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              Consumer<Genres>(
                builder: (context, genres, child) {
                  final items = [DropdownMenuItem<Genre?>(value: null, child: Text("-- No genre --"))];
                  items.addAll(genres.list.map((g) => DropdownMenuItem(value: g, child: Text(g.name))));
                  return DropdownButtonFormField(
                    value: _genre,
                    items: items,
                    onChanged: (genre) => setState(() {
                      _genre = genre;
                    }),
                  );
                }
              ),
              FilePickerWidget(
                onFileChosen: (path) => _filePath = path,
              ),
              Expanded(
                child: TextFormField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  strutStyle: null,
                  maxLength: 2500,
                  decoration: InputDecoration(
                    labelText: "Beginning",
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainer,
                    border: InputBorder.none,
                  ),
                )
              ),
              SizedBox(
                width: 256,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context), 
                      child: Text("Cancel")
                    ),
                    FilledButton(
                      onPressed: _send,
                      child: Text("Create")
                    )
                  ],
                )
              )
            ],
          ))
        )
      )
    );
  }
}