# Quds DB MySQL

A robust, abstract, and highly declarative MySQL database implementation for the `quds_db_interface` ecosystem.

This package provides a seamless ORM-like experience tailored explicitly for MariaDB and MySQL databases in Dart and Flutter. Built upon `mysql_client`, it handles database schemas, connection pooling, indexing, transaction handling, and type-safety invisibly-allowing you to focus strictly on your application's logic.

## Features

*   **Declarative Models:** Define your models in pure Dart; table creation, column definition, and indexing are handled automatically.
*   **Automatic Migrations:** The engine seamlessly creates databases and table structures on initialization if they do not exist.
*   **Type Safety & Type Mapping:** Built-in translations between Dart primitives (including 64-bit DateTimes) and MySQL equivalents (`BIGINT`, `TEXT`, `DOUBLE`).
*   **Performance:** Implements native connection pooling out-of-the-box.
*   **Powerful Query Building:** Supports complex joins, aggregations, paginations, and nested conditions.
*   **Automated Transactions:** Secure bulk insertions and automated rollback handling.
*   **Reactive UI:** Listeners allow widgets to react instantly to database changes (insertions, updates, deletions).

## Getting Started

Add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  quds_db_mysql: ^1.0.0
  quds_db_interface: ^1.0.0
```

## Basic Usage

### 1. Define a Database Model

Create a class extending `StandardDbModel`. Specify your columns using strictly typed fields.

```dart
import 'package:quds_db_interface/quds_db_interface.dart';

class User extends StandardDbModel {
  final name = StringField(columnName: 'name', notNull: true);
  final email = StringField(columnName: 'email', isUnique: true);
  final age = IntField(columnName: 'age', defaultValue: 18);
  final joinDate = DateTimeField(columnName: 'join_date');

  @override
  List<FieldDefinition>? getFields() => [name, email, age, joinDate];
}
```

### 2. Create a Table Provider

Extend the native `MysqlStandardTableProvider` to inject your model and table name.

```dart
import 'package:quds_db_mysql/quds_db_mysql.dart';

class UserProvider extends MysqlStandardTableProvider<User> {
  UserProvider(super.connection, super.modelFactory, super.tableName);
}
```

### 3. Initialize the Adapter and Provider

Set up your adapter with connection details, then initialize the provider. This automatically generates the MySQL schemas and establishes connection pools.

```dart
void main() async {
  final adapter = MysqlDatabaseAdapter();
  
  // Establish connection settings
  await adapter.initialize(
    MysqlDatabaseSettings(
      dbName: 'company_database',
      version: 1,
      host: '127.0.0.1',
      port: 3306,
      userName: 'root',
      password: 'your_password',
    ),
  );

  final connection = await adapter.getConnection() as MysqlDatabaseConnection;

  // Initialize Provider
  final userProvider = UserProvider(connection, () => User(), 'users_table');
  await userProvider.initialize(); // Schema is created here
}
```

## CRUD Operations

The package offers simple methods for standard Data operations.

### Insert Data

```dart
final user = User()
  ..name.value = 'John Doe'
  ..email.value = 'john.doe@example.com'
  ..joinDate.value = DateTime.now();

// Insert a single entry
await userProvider.insertEntry(user);
```

### Query Data

Query results natively return hydrated Dart objects. You can build advanced conditions through lambda functions.

```dart
// Select all users
final allUsers = await userProvider.select();

// Select with condition and sorting
final adultUsers = await userProvider.select(
  where: (u) => u.age.greaterThanOrEqual(18),
  orderBy: (u) => [u.joinDate.descOrder],
);

// Count active records
final count = await userProvider.countWhere(
  (u) => u.email.isNotNull,
);
```

### Update Data

```dart
// Retrieve the user you wish to update
final users = await userProvider.select(where: (u) => u.name.equals('John Doe'));

if (users.isNotEmpty) {
  final user = users.first;
  user.age.value = 35;
  
  await userProvider.updateEntry(user);
}
```

### Delete Data

```dart
// Delete a specific entry
await userProvider.deleteEntry(user);

// Delete entries dynamically
await userProvider.deleteWhere((u) => u.age.lessThan(18));

// Empty the entire table (leaves schema intact)
await userProvider.clear();

// Destroys the table entirely
await userProvider.drop();
```

## Advanced Querying

### Transactions & Bulk Operations

Bulk operations natively wrap operations inside a MySQL transaction logic block. If any insertion fails, the engine safely rolls back.

```dart
try {
  final u1 = User()..name.value = 'Alice';
  final u2 = User()..name.value = 'Bob';

  // Automatically executed inside a single transaction
  await userProvider.insertCollection([u1, u2]);
} catch (e) {
  print('Transaction rolled back due to error.');
}
```

### Joins & Complex Queries

Use the `query()` or `complexQuery()` builders for relational datasets.

```dart
var result = userProvider.query()
  .innerJoin(orderProvider, (user, order) => user.id.equals(order.userId))
  .where((user, order) => order.status.equals('Shipped'))
  .execute();
```

## Architectural Guidelines

The `quds_db_mysql` package strictly translates data between standard interface types to MySQL syntax:
*   `INTEGER` definitions strictly translate to `BIGINT` to support robust 64-bit Dart primitives like `DateTime.millisecondsSinceEpoch`.
*   Standard boolean types are persisted via binary integers (1 and 0).
*   Connection handling is abstracted into managed pooled state ensuring resilience in concurrent applications.
