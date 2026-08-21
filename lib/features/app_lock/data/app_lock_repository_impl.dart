import '../domain/app_lock_repository.dart';
import 'app_lock_account.dart';
import 'app_lock_local_datasource.dart';

class AppLockRepositoryImpl implements AppLockRepository {
  AppLockRepositoryImpl(this._dataSource);

  final AppLockLocalDataSource _dataSource;

  @override
  Future<AppLockAccount?> load() async => _dataSource.read();

  @override
  Future<void> save(AppLockAccount account) => _dataSource.write(account);

  @override
  Future<void> clear() => _dataSource.clear();
}
