import 'dart:async';
import 'package:mysql_client/mysql_client.dart';
import 'package:quds_db_interface/quds_db_interface.dart';

class MysqlDatabaseConnection extends DatabaseConnection {
  final MySQLConnectionPool _pool;
  static final _transactionKey = Object();
  bool _isClosed = false;

  MysqlDatabaseConnection(this._pool);

  @override
  bool get isOpen => !_isClosed;

  dynamic _getConnection() {
    final activeTx = Zone.current[_transactionKey];
    if (activeTx != null) {
      return activeTx;
    }
    return _pool;
  }

  @override
  Future<void> close() async {
    _isClosed = true;
    // Normally pool is closed in the Adapter
  }

  @override
  Future<int> execute(String sql, [List<dynamic>? parameters]) async {
    final conn = _getConnection();
    var outQuery = [sql];
    final params = _convertToNamedParams(sql, parameters ?? [], outQuery);
    final result = await conn.execute(outQuery[0], params);
    return result.affectedRows.toInt();
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? parameters]) async {
    final conn = _getConnection();
    var outQuery = [sql];
    final params = _convertToNamedParams(sql, parameters ?? [], outQuery);
    final result = await conn.execute(outQuery[0], params);
    return result.rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row.assoc())).toList();
  }

  @override
  Future<int?> insert(String tableName, Map<String, dynamic> values) async {
    final keys = values.keys.join(', ');
    final placeholders = values.keys.map((_) => '?').join(', ');
    final sql = 'INSERT INTO $tableName ($keys) VALUES ($placeholders)';
    
    final conn = _getConnection();
    var outQuery = [sql];
    final params = _convertToNamedParams(sql, values.values.toList(), outQuery);
    final result = await conn.execute(outQuery[0], params);
    return result.lastInsertID.toInt();
  }

  @override
  Future<int> update(String tableName, Map<String, dynamic> values, String where, [List<dynamic>? parameters]) async {
    final assignments = values.keys.map((k) => '$k = ?').join(', ');
    final sql = 'UPDATE $tableName SET $assignments WHERE $where';
    
    final paramsList = values.values.toList();
    if (parameters != null) {
      paramsList.addAll(parameters);
    }
    
    final conn = _getConnection();
    var outQuery = [sql];
    final params = _convertToNamedParams(sql, paramsList, outQuery);
    final result = await conn.execute(outQuery[0], params);
    return result.affectedRows.toInt();
  }

  @override
  Future<int> delete(String tableName, String where, [List<dynamic>? parameters]) async {
    final sql = 'DELETE FROM $tableName WHERE $where';
    final conn = _getConnection();
    var outQuery = [sql];
    final params = _convertToNamedParams(sql, parameters ?? [], outQuery);
    final result = await conn.execute(outQuery[0], params);
    return result.affectedRows.toInt();
  }

  @override
  Future<T> transaction<T>(Future<T> Function() operation) async {
    if (Zone.current[_transactionKey] != null) {
      return await operation();
    }
    return await _pool.transactional((conn) async {
      return await runZoned(
        () async {
          return await operation();
        },
        zoneValues: {_transactionKey: conn},
      );
    });
  }

  Map<String, dynamic> _convertToNamedParams(String sql, List<dynamic> params, List<String> outQuery) {
    if (params.isEmpty && !sql.contains('?')) {
      return {};
    }
    var queryBuffer = StringBuffer();
    var mappedParams = <String, dynamic>{};
    int paramIndex = 0;
    bool inString = false;
    
    for (int i = 0; i < sql.length; i++) {
      var char = sql[i];
      if (char == "'") {
        inString = !inString;
        queryBuffer.write(char);
      } else if (char == '?' && !inString) {
        if (paramIndex < params.length) {
          var paramName = 'p$paramIndex';
          queryBuffer.write(':$paramName');
          
          // mysql_client requires boolean parameters to be 0 or 1.
          var val = params[paramIndex];
          if (val == true) val = 1;
          if (val == false) val = 0;
          if (val is DateTime) val = val.millisecondsSinceEpoch;
          
          mappedParams[paramName] = val;
          paramIndex++;
        } else {
          queryBuffer.write(char); 
        }
      } else {
        queryBuffer.write(char);
      }
    }
    outQuery[0] = queryBuffer.toString();
    return mappedParams;
  }
}
