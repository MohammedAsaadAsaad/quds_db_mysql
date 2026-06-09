import 'package:quds_db_mysql/quds_db_mysql.dart';

void main() async {
  final adapter = MysqlDatabaseAdapter();
  await adapter.initialize(
    MysqlDatabaseSettings(
      dbName: 'quds_demo',
      version: 1,
      host: '127.0.0.1',
      port: 2020,
      userName: 'root',
      password: '0',
    ),
  );
  final connection = await adapter.getConnection() as MysqlDatabaseConnection;
  try {
    final result = await connection.query('SHOW COLUMNS FROM Tasks');
    for (var row in result) {
      print('\${row["Field"]}: \${row["Type"]}');
    }
  } catch (e) {
    print('Error: \$e');
  }
  await adapter.close();
}
