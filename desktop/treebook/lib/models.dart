class Book {
  const Book({required this.id, required this.title, required this.author, required this.firstPageId, this.genre, this.imagePath});
  
  final String id;
  final String title;
  final User author;
  final Genre? genre;
  final String? imagePath;
  final String firstPageId;

  factory Book.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': String id,
        'title': String title,
        'author_id': String authorId,
        'author': String author,
        'first_page_id': String firstPageId,
        'genre_id': String? genreId,
        'genre': String? genre,
        'image_path': String? imagePath
      } =>
        Book(
          id: id,
          title: title,
          firstPageId: firstPageId,
          author: User(
            id: authorId,
            username: author
          ),
          genre: (genreId != null && genre != null)? Genre(
            id: genreId,
            name: genre
          ) : null,
          imagePath: imagePath,
        ),
      _ => throw const FormatException('Failed to parse book.'),
    };
  }
}

class User {
  const User({required this.id, required this.username});

  final String id;
  final String username;
  
}

class Genre {
  const Genre({required this.id, required this.name});

  final String id;
  final String name;

  factory Genre.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': String id,
        'name': String name
      } => 
        Genre(
          id: id,
          name: name
        ),
      _ => throw const FormatException('Failed to parse genre.'),
    };
  }
}

class Page_ {
  Page_({
    required this.id, 
    required this.bookId, 
    required this.bookTitle,
    required this.text, 
    required this.first, 
    required this.last, 
    required this.author, 
    required this.createdAt, 
    required this.likesCount, 
    this.prevPageId
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final String text;
  final bool first;
  final bool last;
  final String? prevPageId;
  final User author;
  final DateTime createdAt;
  final int likesCount;

  factory Page_.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': String id,
        'book_id': String bookId,
        'book_title': String bookTitle,
        'text': String text,
        'first': bool first,
        'last': bool last,
        'previous_page_id': String? prevPageId,
        'author_id': String authorId,
        'author': String author,
        'created_at': String createdAt,
        'likes_count': int likesCount
      } =>
        Page_(
          id: id,
          bookId: bookId,
          bookTitle: bookTitle,
          text: text,
          first: first,
          last: last,
          prevPageId: prevPageId,
          author: User(
            id: authorId,
            username: author
          ),
          createdAt: DateTime.parse(createdAt),
          likesCount: likesCount,
        ),
      _ => throw const FormatException('Failed to parse page.'),
    };
  }
}