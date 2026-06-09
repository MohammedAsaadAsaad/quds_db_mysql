import 'package:mysql_client/mysql_client.dart';
import 'package:quds_db_interface/quds_db_interface.dart';
import 'mysql_database_connection.dart';

class MysqlDatabaseSettings extends DatabaseSettings {
  final String dbName;
  final int version;
  final String host;
  final int port;
  final String userName;
  final String password;

  MysqlDatabaseSettings({
    required this.dbName,
    required this.version,
    this.host = '127.0.0.1',
    this.port = 3306,
    this.userName = 'root',
    this.password = '',
  });
}

class MysqlDatabaseAdapter extends DatabaseAdapter {
  MySQLConnectionPool? _pool;
  MysqlDatabaseSettings? _settings;

  @override
  Future<void> initialize(DatabaseSettings settings) async {
    _settings = settings as MysqlDatabaseSettings;
    
    final setupConn = await MySQLConnection.createConnection(
      host: _settings!.host,
      port: _settings!.port,
      userName: _settings!.userName,
      password: _settings!.password,
      secure: false,
    );
    await setupConn.connect();
    await setupConn.execute('CREATE DATABASE IF NOT EXISTS \`${_settings!.dbName}\`');
    await setupConn.close();

    _pool = MySQLConnectionPool(
      host: _settings!.host,
      port: _settings!.port,
      userName: _settings!.userName,
      password: _settings!.password,
      databaseName: _settings!.dbName,
      secure: false,
      maxConnections: 10,
    );
  }

  @override
  Future<DatabaseConnection> getConnection() async {
    if (_pool == null) throw Exception('Not initialized');
    return MysqlDatabaseConnection(_pool!);
  }

  @override
  Future<void> close() async {
    await _pool?.close();
  }

  @override
  Future<int> rawExecute(String sql, [List<dynamic>? parameters]) async {
    final conn = await getConnection();
    return await conn.execute(sql, parameters);
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? parameters]) async {
    final conn = await getConnection();
    return await conn.query(sql, parameters);
  }
}
