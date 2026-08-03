import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';
import 'settings_local_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._dataSource);

  final SettingsLocalDataSource _dataSource;

  @override
  Future<AppSettings> load() async => _dataSource.read();

  @override
  Future<void> save(AppSettings settings) => _dataSource.write(settings);
}
