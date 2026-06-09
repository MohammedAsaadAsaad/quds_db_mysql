import 'package:flutter_test/flutter_test.dart';
import 'package:quds_db_mysql/quds_db_mysql.dart';

class Note extends StandardDbModel {
  final title = StringField(columnName: 'title', notNull: true);
  final isImportant = BoolField(columnName: 'isImportant', defaultValue: false);

  @override
  List<FieldDefinition>? getFields() => [title, isImportant];
}

class NoteProvider extends MysqlStandardTableProvider<Note> {
  NoteProvider(super.connection, super.modelFactory, super.tableName);
}

void main() {
  late MysqlDatabaseAdapter adapter;
  late NoteProvider provider;

  setUpAll(() async {
    adapter = MysqlDatabaseAdapter();
    await adapter.initialize(
      MysqlDatabaseSettings(
        dbName: 'test_db',
        version: 1,
        host: '127.0.0.1',
        port: 2020,
        userName: 'root',
        password: '0',
      ),
    );

    final conn = await adapter.getConnection() as MysqlDatabaseConnection;
    provider = NoteProvider(conn, () => Note(), 'notes_table');
    await provider.initialize();
  });

  tearDownAll(() async {
    await provider.drop();
  });

  group('CRUD Operations', () {
    test('Insert and Select', () async {
      await provider.clear();

      final note = Note()
        ..title.value = 'My MySQL Note'
        ..isImportant.value = true;

      final id = await provider.insertEntry(note);
      expect(id, isNotNull);

      final allNotes = await provider.select();
      expect(allNotes.length, equals(1));
      expect(allNotes.first.title.value, equals('My MySQL Note'));
      expect(allNotes.first.isImportant.value, equals(true));
    });

    test('Bulk Transactions', () async {
      await provider.clear();

      final notes = List.generate(50, (i) => Note()..title.value = 'Batch \$i');
      await provider.insertCollection(notes);

      final count = await provider.count();
      expect(count, equals(50));
    });
  });
}
