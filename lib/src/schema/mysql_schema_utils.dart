import 'package:quds_db_interface/quds_db_interface.dart';

class MysqlSchemaUtils {
  static String mapToColumnDef(FieldDefinition field) {
    String def = field.columnDefinition;
    def = def.replaceAll('INTEGER', 'BIGINT');
    def = def.replaceAll('REAL', 'DOUBLE');
    def = def.replaceAll('AUTOINCREMENT', 'AUTO_INCREMENT');
    return def;
  }

  static String mapBoolColumnDef(BoolField field) {
    final parts = <String>['BOOLEAN'];
    if (field.value != null) {
      parts.add('DEFAULT ${field.value! ? 1 : 0}');
    }
    if (field.notNull == true) parts.add('NOT NULL');
    return '`${field.columnName}` ${parts.join(' ')}';
  }

  static bool isBooleanType(String? nativeType) {
    if (nativeType == null) return false;
    final t = nativeType.toLowerCase();
    return t == 'tinyint(1)' ||
        t == 'boolean' ||
        t == 'bool' ||
        t.startsWith('tinyint');
  }

  static String booleanCoerceExpression(
    String column,
    String nativeType,
    int defaultLiteral,
  ) {
    final t = nativeType.toLowerCase();
    if (t.contains('int') ||
        t == 'decimal' ||
        t == 'numeric' ||
        t == 'double' ||
        t == 'float' ||
        t == 'real') {
      return 'CASE WHEN `$column` IS NULL THEN $defaultLiteral ELSE `$column` <> 0 END';
    }
    if (t.contains('char') || t == 'text') {
      return '''CASE
        WHEN `$column` IS NULL THEN $defaultLiteral
        WHEN LOWER(TRIM(`$column`)) IN ('true', 't', '1', 'yes') THEN 1
        ELSE 0
      END''';
    }
    return 'CASE WHEN `$column` IS NULL THEN $defaultLiteral ELSE 0 END';
  }
}
