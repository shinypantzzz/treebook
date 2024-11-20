import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'config.dart';
import 'models.dart';
import 'exceptions.dart';

class ApiClient extends ChangeNotifier {
  ApiClient() : anonymous = true;

  bool anonymous;
  String? username;

  String? _password;
  String? _authToken;

  Future<void> create(String username, String password) async {
    final Uri url = Uri.http('$API_BASE_URL:$API_PORT', '/register_user');
    final response = await http.post(url, body: {'username': username, 'password': password});
    if (response.statusCode == 201) {
      anonymous = false;
      this.username = username;
      _password = password;
      _authToken = response.headers['authorization'];
      notifyListeners();
    } else {
      switch (response.statusCode) {
        case 400:
          switch (response.reasonPhrase) {
            case "INVALID_USERNAME":
              throw InvalidUsernameException();
            case "INVALID_PASSWORD":
              throw InvalidPasswordException();
          }
        case 409:
          throw UserAlreadyExistsException();
        default:
          throw ServerErrorException();
      }
    }
  }

  Future<void> connect(String username, String password) async {
    Uri url = Uri.http('$API_BASE_URL:$API_PORT', '/login_user');
    final response = await http.post(url, body: {'username': username, 'password': password});
    if (response.statusCode == 200) {
      _authToken = response.headers['authorization'];
      this.username = username;
      _password = password;
      anonymous = false;
      notifyListeners();
    } else {
      switch (response.statusCode) {
        case 401:
          throw WrongPasswordException();
        case 404:
          throw UserDoesNotExistException();
        case 500:
          throw ServerErrorException();
      }
    }
  }

  void disconnect() {
    _authToken = null;
    username = null;
    _password = null;
    anonymous = true;
    notifyListeners();
  }

  Future<Book> fetchBook(String bookId) async {
    var params = <String, String>{'book_id': bookId};
    Uri url = Uri.http('$API_BASE_URL:$API_PORT', '/book', params);

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final bookData = jsonDecode(response.body) as Map<String, dynamic>;
      return Book.fromJson(bookData);
    } else {
      throw ServerErrorException();
    }
  }

  Future<List<Book>> fetchBooks(Map<String, String> filters, String orderBy, bool desc, int offset, int limit) async {
    Map<String, String> params = {};
    params.addAll(filters);
    params['order_by'] = orderBy;
    if (desc) params['desc'] = 'true';
    params['offset'] = '$offset';
    params['limit'] = '$limit'; 
    Uri url = Uri.http('$API_BASE_URL:$API_PORT', '/books', params);

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final books = jsonDecode(response.body) as List<dynamic>;
      return books.map((bookData) => Book.fromJson(bookData)).toList();
    } else {
      return [];
    }
  }

  Future<Map<String, dynamic>> postBook ({required String title, required String text, String? genreId, String? coverPath}) async {
    if (_authToken == null) {
      throw AuthorizationRequiredException();
    }
    Uri url = Uri.http(API_ROOT, '/book');
    http.MultipartRequest request = http.MultipartRequest('post', url);
    request.headers['Authorization'] = _authToken!;
    request.fields['title'] = title;
    request.fields['text'] = text;
    if (genreId!= null) request.fields['genre_id'] = genreId;
    if (coverPath!= null) {
      request.files.add(http.MultipartFile.fromBytes('cover', File(coverPath).readAsBytesSync(), filename: 'cover.jpg'));
    }

    final response = await request.send();

    if (response.statusCode == 201) {
      var responseBody = '';
      await for (final event in response.stream) {
        final part = utf8.decode(event);
        responseBody += part;
      }
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      switch (response.statusCode) {
        case 401:
          switch (response.reasonPhrase) {
            case "UNAUTHORIZED":
              throw AuthorizationRequiredException();
            case "BAD_TOKEN":
              await connect(username!, _password!);
              return await postBook(title: title, text: text, genreId: genreId, coverPath: coverPath);
            default:
              throw AuthorizationException();
          }
        case 400:
          switch (response.reasonPhrase) {
            case "INVALID_TITLE":
              throw InvalidTitleException();
            case "INVALID_FIRST_PAGE_TEXT":
              throw InvalidPageTextException();
            default:
              throw ValidationException();
          }
        default:
          throw ServerErrorException();
      }
    }
  }

  Future<Page_> fetchPage(String pageId) async {
    var params = <String, String>{'page_id': pageId};
    Uri url = Uri.http('$API_BASE_URL:$API_PORT', '/page', params);

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final bookData = jsonDecode(response.body) as Map<String, dynamic>;
      return Page_.fromJson(bookData);
    } else {
      throw ServerErrorException();
    }
  }

  Future<List<Page_>> fetchPages(Map<String, String> filters, String orderBy, bool desc, int offset, int limit) async {
    Map<String, String> params = {};
    params.addAll(filters);
    params['order_by'] = orderBy;
    if (desc) params['desc'] = 'true';
    params['offset'] = '$offset';
    params['limit'] = '$limit'; 
    Uri url = Uri.http(API_ROOT, '/pages', params);

    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final pages = jsonDecode(response.body) as List<dynamic>;
      return pages.map((pageData) => Page_.fromJson(pageData)).toList();
    } else {
      return [];
    }
  }

  Future<String> postPage(String prevPageId, String text, bool last) async {
    if (_authToken == null) {
      throw AuthorizationRequiredException();
    }
    Uri url = Uri.http(API_ROOT, '/page');

    final params = <String, String>{
      'prev_page_id': prevPageId,
      'text': text,
    };
    if (last) {
      params['last'] = 'true';
    }
    
    final response = await http.post(url, headers: {'Authorization': _authToken!}, body: params);

    if (response.statusCode == 201) {
      return (jsonDecode(response.body) as Map)['page_id'];
    } else {
      switch (response.statusCode) {
        case 401:
          switch (response.reasonPhrase) {
            case "UNAUTHORIZED":
              throw AuthorizationRequiredException();
            case "BAD_TOKEN":
              await connect(username!, _password!);
              return await postPage(prevPageId, text, last);
            default:
              throw AuthorizationException();
          }
        case 400:
          throw InvalidPageTextException();
        case 404:
          throw PageNotFoundException();
        case 409:
          throw LastPageException();
        default:
          throw ServerErrorException();
      }
    }
  }

  Stream<List<Genre>> fetchGenres() async* {
    int limit = 100;
    int offset = 0;
    int tries = 0;
    while (true) {
      if (tries > 10) {
        throw ServerErrorException();
      }
      Uri url = Uri.http(API_ROOT, '/genres', {'offset': '$offset', 'limit': '$limit'});
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        if ((jsonDecode(response.body) as List).isEmpty) {
          return;
        }
        final data = jsonDecode(response.body) as List<dynamic>;
        yield data.map((val) => Genre.fromJson(val)).toList();
        offset += limit;
      } else {
        tries += 1;
        continue;
      }
    }
  }
}