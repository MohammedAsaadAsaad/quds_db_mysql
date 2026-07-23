import 'package:quds_db_interface/quds_db_interface.dart';
import 'package:quds_db_mysql/quds_db_mysql.dart';
import 'package:test/test.dart';

class SchemaNote extends StandardDbModel {
  final title = StringField(columnName: 'title', notNull: true);
  final isImportant = BoolField(columnName: 'isImportant', defaultValue: false);

  @override
  List<FieldDefinition>? getFields() => [title, isImportant];
}

class SchemaNoteProvider extends MysqlStandardTableProvider<SchemaNote> {
  SchemaNoteProvider(super.connection, super.modelFactory, super.tableName);
}

void main() {
  late MysqlDatabaseAdapter adapter;
  late MysqlDatabaseConnection connection;
  late SchemaNoteProvider provider;

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

    connection = await adapter.getConnection() as MysqlDatabaseConnection;
    provider = SchemaNoteProvider(connection, () => SchemaNote(), 'schema_notes');
    await provider.initialize();
  });

  tearDown(() async {
    await connection.execute('DROP TABLE IF EXISTS mysql_bool_bigint_test');
    await connection.execute('DROP TABLE IF EXISTS mysql_bool_text_test');
    await connection.execute('DROP TABLE IF EXISTS mysql_bool_missing_test');
    await connection.execute('DROP TABLE IF EXISTS mysql_ensure_field_test');
  });

  tearDownAll(() async {
    await provider.drop();
    await adapter.close();
  });

  group('SchemaInspector', () {
    test('tableExists returns true for initialized provider table', () async {
      expect(await connection.schema.tableExists('schema_notes'), isTrue);
    });

    test('columnExists detects present and missing columns', () async {
      expect(await connection.schema.columnExists('schema_notes', 'title'), isTrue);
      expect(await connection.schema.columnExists('schema_notes', 'missing'), isFalse);
    });

    test('columnNativeType returns mysql type name', () async {
      final type = await connection.schema.columnNativeType('schema_notes', 'title');
      expect(type, isNotNull);
      expect(type, anyOf(contains('varchar'), contains('text')));
    });

    test('listColumns returns metadata for all columns', () async {
      final columns = await connection.schema.listColumns('schema_notes');
      expect(columns.map((c) => c.name), contains('title'));
      expect(columns.map((c) => c.name), contains('isImportant'));
    });
  });

  group('SchemaMigrator.ensureBooleanNotNull', () {
    test('adds missing boolean column with default and NOT NULL', () async {
      await connection.execute(
        'CREATE TABLE mysql_bool_missing_test (id BIGINT PRIMARY KEY AUTO_INCREMENT)',
      );

      final field = BoolField(
        columnName: 'is_active',
        defaultValue: true,
        notNull: true,
      );

      await connection.migration.ensureBooleanNotNull('mysql_bool_missing_test', field);

      expect(await connection.schema.columnExists('mysql_bool_missing_test', 'is_active'), isTrue);
      final type = await connection.schema.columnNativeType('mysql_bool_missing_test', 'is_active');
      expect(type, isNotNull);
    });

    test('coerces legacy integer column to boolean', () async {
      await connection.execute(
        'CREATE TABLE mysql_bool_bigint_test (legacy_flag BIGINT)',
      );
      await connection.execute(
        'INSERT INTO mysql_bool_bigint_test (legacy_flag) VALUES (1), (0), (NULL)',
      );

      final field = BoolField(
        columnName: 'legacy_flag',
        defaultValue: false,
        notNull: true,
      );

      await connection.migration.ensureBooleanNotNull('mysql_bool_bigint_test', field);

      final rows = await connection.query('SELECT legacy_flag FROM mysql_bool_bigint_test');
      expect(rows.every((r) => r['legacy_flag'] == 0 || r['legacy_flag'] == 1), isTrue);
    });

    test('coerces legacy text column to boolean', () async {
      await connection.execute(
        'CREATE TABLE mysql_bool_text_test (legacy_text TEXT)',
      );
      await connection.execute(
        "INSERT INTO mysql_bool_text_test (legacy_text) VALUES ('true'), ('false'), ('1'), (NULL)",
      );

      final field = BoolField(
        columnName: 'legacy_text',
        defaultValue: false,
        notNull: true,
      );

      await connection.migration.ensureBooleanNotNull('mysql_bool_text_test', field);

      final rows = await connection.query('SELECT legacy_text FROM mysql_bool_text_test');
      expect(rows.every((r) => r['legacy_text'] == 0 || r['legacy_text'] == 1), isTrue);
    });

    test('safe mode does not throw on repeated migration', () async {
      await connection.execute(
        'CREATE TABLE mysql_bool_missing_test (flag BOOLEAN NOT NULL DEFAULT FALSE)',
      );

      final field = BoolField(
        columnName: 'flag',
        defaultValue: false,
        notNull: true,
      );

      await connection.migration.ensureBooleanNotNull(
        'mysql_bool_missing_test',
        field,
        safe: true,
      );
    });
  });

  group('TableProvider schema helpers', () {
    test('ensureField adds a new column through migration API', () async {
      await connection.execute(
        'CREATE TABLE mysql_ensure_field_test (id BIGINT PRIMARY KEY AUTO_INCREMENT)',
      );

      final nickname = StringField(columnName: 'nickname', defaultValue: 'anon');
      await connection.migration.ensureField('mysql_ensure_field_test', nickname);

      expect(await connection.schema.columnExists('mysql_ensure_field_test', 'nickname'), isTrue);
    });

    test('provider exposes ensureBooleanNotNull without throwing', () async {
      final field = BoolField(
        columnName: 'isImportant',
        defaultValue: false,
        notNull: true,
      );

      await provider.ensureBooleanNotNull(field, safe: true);
      expect(await connection.schema.columnExists('schema_notes', 'isImportant'), isTrue);
    });
  });
}
