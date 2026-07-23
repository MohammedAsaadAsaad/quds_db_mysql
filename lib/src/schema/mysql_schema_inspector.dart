import 'package:quds_db_interface/quds_db_interface.dart';
import '../adapters/mysql_database_connection.dart';

class MysqlSchemaInspector implements SchemaInspector {
  final MysqlDatabaseConnection connection;

  MysqlSchemaInspector(this.connection);

  @override
  Future<bool> tableExists(String table, {String? schema}) async {
    final result = await connection.query(
      '''
SELECT 1
FROM information_schema.tables
WHERE table_schema = COALESCE(?, DATABASE())
  AND table_name = ?
LIMIT 1
''',
      [schema, table],
    );
    return result.isNotEmpty;
  }

  @override
  Future<bool> columnExists(
    String table,
    String column, {
    String? schema,
  }) async {
    final result = await connection.query(
      '''
SELECT 1
FROM information_schema.columns
WHERE table_schema = COALESCE(?, DATABASE())
  AND table_name = ?
  AND column_name = ?
LIMIT 1
''',
      [schema, table, column],
    );
    return result.isNotEmpty;
  }

  @override
  Future<String?> columnNativeType(
    String table,
    String column, {
    String? schema,
  }) async {
    final result = await connection.query(
      '''
SELECT COLUMN_TYPE AS native_type
FROM information_schema.columns
WHERE table_schema = COALESCE(?, DATABASE())
  AND table_name = ?
  AND column_name = ?
''',
      [schema, table, column],
    );
    if (result.isEmpty) return null;
    return result.first['native_type']?.toString().toLowerCase();
  }

  @override
  Future<List<ColumnInfo>> listColumns(String table, {String? schema}) async {
    final result = await connection.query(
      '''
SELECT
  column_name,
  column_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = COALESCE(?, DATABASE())
  AND table_name = ?
ORDER BY ordinal_position
''',
      [schema, table],
    );

    return result
        .map(
          (row) => ColumnInfo(
            name: row['column_name']?.toString() ?? '',
            nativeType: row['column_type']?.toString().toLowerCase() ?? '',
            isNullable:
                row['is_nullable']?.toString().toUpperCase() == 'YES',
            hasDefault: row['column_default'] != null,
          ),
        )
        .toList();
  }
}
