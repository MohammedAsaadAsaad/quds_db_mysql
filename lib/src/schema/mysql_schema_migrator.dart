import 'package:quds_db_interface/quds_db_interface.dart';
import '../adapters/mysql_database_connection.dart';
import 'mysql_schema_inspector.dart';
import 'mysql_schema_utils.dart';

class MysqlSchemaMigrator implements SchemaMigrator {
  final MysqlDatabaseConnection connection;
  late final MysqlSchemaInspector _inspector = MysqlSchemaInspector(connection);

  MysqlSchemaMigrator(this.connection);

  @override
  SchemaInspector get inspector => _inspector;

  @override
  Future<void> ensureField(String table, FieldDefinition field) async {
    final column = field.columnName;
    if (column == null || column == 'id') return;

    if (field is BoolField) {
      if (field.notNull == true) {
        await ensureBooleanNotNull(table, field);
      } else {
        await _ensureBooleanColumn(table, field);
      }
      if (field.isIndexed) await _ensureIndex(table, field);
      return;
    }

    final exists = await _inspector.columnExists(table, column);
    if (!exists) {
      await connection.execute(
        'ALTER TABLE $table ADD COLUMN ${MysqlSchemaUtils.mapToColumnDef(field)}',
      );
    } else if (field is FieldWithValue && field.notNull == true) {
      await _backfillAndSetNotNull(table, column, field.value);
    }

    if (field is FieldWithValue && field.isIndexed) {
      await _ensureIndex(table, field);
    }
  }

  @override
  Future<void> ensureBooleanNotNull(
    String table,
    BoolField field, {
    bool safe = false,
  }) async {
    try {
      await _ensureBooleanNotNullInternal(table, field);
    } catch (e) {
      if (safe) {
        // ignore: avoid_print
        print('Migration warning ($table.${field.columnName}): $e');
      } else {
        rethrow;
      }
    }
  }

  Future<void> _ensureBooleanNotNullInternal(String table, BoolField field) async {
    final column = field.columnName;
    if (column == null) return;

    final defaultValue = field.value ?? false;
    final literal = defaultValue ? 1 : 0;
    final exists = await _inspector.columnExists(table, column);
    final nativeType =
        exists ? await _inspector.columnNativeType(table, column) : null;

    if (!exists) {
      await connection.execute(
        'ALTER TABLE $table ADD COLUMN ${MysqlSchemaUtils.mapBoolColumnDef(field)}',
      );
    } else if (!MysqlSchemaUtils.isBooleanType(nativeType)) {
      final using = MysqlSchemaUtils.booleanCoerceExpression(
        column,
        nativeType ?? 'unknown',
        literal,
      );
      await connection.execute(
        'ALTER TABLE $table MODIFY COLUMN `$column` BOOLEAN NOT NULL DEFAULT $literal',
      );
      await connection.execute(
        'UPDATE $table SET `$column` = ($using) WHERE `$column` IS NULL OR 1=1',
      );
    }

    await connection.execute(
      'UPDATE $table SET `$column` = $literal WHERE `$column` IS NULL',
    );

    try {
      await connection.execute(
        'ALTER TABLE $table MODIFY COLUMN `$column` BOOLEAN NOT NULL DEFAULT $literal',
      );
    } catch (_) {
      // Already NOT NULL or unsupported change.
    }
  }

  Future<void> _ensureBooleanColumn(String table, BoolField field) async {
    final column = field.columnName;
    if (column == null) return;

    final exists = await _inspector.columnExists(table, column);
    if (!exists) {
      await connection.execute(
        'ALTER TABLE $table ADD COLUMN ${MysqlSchemaUtils.mapBoolColumnDef(field)}',
      );
    }
  }

  Future<void> _backfillAndSetNotNull(
    String table,
    String column,
    dynamic defaultValue,
  ) async {
    if (defaultValue != null) {
      await connection.execute(
        'UPDATE $table SET `$column` = ? WHERE `$column` IS NULL',
        [defaultValue],
      );
    }
    try {
      await connection.execute(
        'ALTER TABLE $table MODIFY COLUMN `$column` NOT NULL',
      );
    } catch (_) {}
  }

  Future<void> _ensureIndex(String table, FieldWithValue field) async {
    final column = field.columnName;
    if (column == null) return;
    try {
      await connection.execute(
        'CREATE INDEX idx_${table}_$column ON $table (`$column`)',
      );
    } catch (_) {}
  }
}
