import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/repository/content_repository.dart';
import '../../services/audio_cache_service.dart';
import '../../services/settings_cubit.dart';
import '../library/library_cubit.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.cacheStats,
    this.audioFileCount = 0,
    this.audioBytes = 0,
    this.appVersion = '',
  });

  final CacheStats? cacheStats;
  final int audioFileCount;
  final int audioBytes;
  final String appVersion;

  String get audioSizeText => _readableSize(audioBytes);

  ProfileState copyWith({
    CacheStats? cacheStats,
    int? audioFileCount,
    int? audioBytes,
    String? appVersion,
  }) {
    return ProfileState(
      cacheStats: cacheStats ?? this.cacheStats,
      audioFileCount: audioFileCount ?? this.audioFileCount,
      audioBytes: audioBytes ?? this.audioBytes,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  static String _readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props =>
      [cacheStats, audioFileCount, audioBytes, appVersion];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required SettingsCubit settings,
    required AudioCacheService audioCache,
    required ContentRepository repo,
    required LibraryCubit library,
  })  : _settings = settings,
        _audioCache = audioCache,
        _repo = repo,
        _library = library,
        super(const ProfileState()) {
    refreshStats();
    _loadVersion();
  }

  final SettingsCubit _settings;
  final AudioCacheService _audioCache;
  final ContentRepository _repo;
  final LibraryCubit _library;

  SettingsCubit get settings => _settings;

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    emit(state.copyWith(appVersion: '${info.version}+${info.buildNumber}'));
  }

  Future<void> refreshStats() async {
    final stats = await _repo.cacheStats();
    final audio = await _audioCache.stats();
    emit(state.copyWith(
      cacheStats: stats,
      audioFileCount: audio.files,
      audioBytes: audio.bytes,
    ));
  }

  /// 清掉课文 JSON + 音频等本地资源，方便拉到服务端最新内容。
  Future<void> clearAllCaches() async {
    await _audioCache.clear();
    await _repo.clearCache();
    await refreshStats();
    await _library.reload();
  }

  /// 换内容源后缓存里的 etag 和音频都对不上了，一起清掉重拉。
  Future<void> applyBaseUrl(String url) async {
    _settings.setContentBaseUrl(url);
    await clearAllCaches();
  }
}
