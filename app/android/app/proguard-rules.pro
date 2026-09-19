# Flutter 引擎与插件通道的规则由 Flutter Gradle 插件自动注入，这里只放本项目额外需要的。
#
# 课文 JSON 全部手写 fromJson，不走反射，所以不需要为数据模型加 keep 规则。
# 真要加字段反射（比如将来引 json_serializable 之外的方案）时，记得在这里补 -keep。

# sqlite3_flutter_libs 通过 JNI 加载原生库
-keep class com.tekartik.** { *; }
-keep class io.github.simolus3.** { *; }

# flutter_tts 回调依赖方法名
-keep class com.tundralabs.fluttertts.** { *; }
