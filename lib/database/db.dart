import 'app_database.dart';

AppDatabase? _db;

AppDatabase get appDatabase {
  _db ??= AppDatabase();
  return _db!;
}
