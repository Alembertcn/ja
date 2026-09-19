# ja — 日语学习资料与学习 App

本仓库同时是**日语学习笔记**和**「JA 日语精读」App 的内容源**。

学习资料用 Markdown 写给人看；课文用结构化 JSON 写给 App 看。JSON 由 AI 按学习计划预先生成并提交入库，经构建脚本校验后发布到 GitHub Pages，Flutter App 直接拉取渲染，不需要任何后端服务。

---

## 目录导航

| 目录 | 内容 |
|------|------|
| [docs/exam/](docs/exam/) | JLPT 报考流程、材料、网址与注意事项 |
| [docs/plan/](docs/plan/) | 学习计划与知识点大纲（模块编号 `G2-E01` 等是 AI 生成课文的索引） |
| [docs/lessons/](docs/lessons/) | 人工整理的精讲笔记（Markdown） |
| [content/](content/) | 课文数据源（JSON），App 的内容源头 |
| [audio/](audio/) | 逐句预生成的日语音频，由 `tools/tts.py` 产出并入库 |
| [prompts/](prompts/) | 给 AI 的固定生成模板 |
| [tools/](tools/) | 构建与合成脚本（Python） |
| [app/](app/) | Flutter 客户端工程 |
| `dist/` | 构建产物，不入库，由 CI 生成并发布到 Pages |

### 文档索引

- [JLPT报考指南](docs/exam/JLPT报考指南.md) — 报名、缴费、准考证、考试日、查分、领证全流程
- [N2学习计划_2027年7月](docs/plan/N2学习计划_2027年7月.md) — 42 周计划、四阶段路线、知识点大纲、AI 提示词模板
- [第一次见面_对话精讲](docs/lessons/第一次见面_对话精讲.md) — 入门对话逐句精讲与 TTS 工具推荐

---

## 内容是怎么流转的

```text
docs/plan/ 学习计划（模块编号）
      ↓  按 prompts/ 模板让 AI 生成
content/articles/*.json  ← 结构化课文，人工校对后提交
      ↓  python tools/tts.py     逐句合成日语音频
audio/<课文 id>/<行 id>.mp3      ← 一并入库
      ↓  python tools/build.py   校验 + 注入音频路径
dist/manifest.json + dist/articles/*.json + dist/audio/
      ↓  GitHub Actions
GitHub Pages（公开 CDN）
      ↓  HTTPS + ETag 增量拉取
Flutter App（列表 / 详情逐行精讲 / 逐句朗读）
```

## 常用命令

新增一篇课文：

1. 在 Cursor 里按 [prompts/生成课文.md](prompts/生成课文.md) 指定周次与语法模块，让 AI 产出 JSON；
2. 保存到 `content/articles/<id>.json`，人工校对读音与解析；
3. 合成音频并构建：

```bash
pip install edge-tts
python tools/tts.py              # 只补缺失或文本变过的句子
python tools/tts.py --list-voices
python tools/build.py            # 校验 content/ 并生成 dist/
python tools/build.py --check    # 只校验，不写文件（CI 用）
```

4. 提交推送，GitHub Actions 自动发布，App 下拉刷新即可看到。

## 关于朗读

App 优先播 `audio/` 里预生成的音频，只有这句没有音频、或者下载失败时才回落到手机系统 TTS。这样即使手机上一个 TTS 引擎都没装（国行 ROM 很常见）也能正常听。详情页右上角可以把整篇音频一次性下到本地，之后断网也能播。

音频用 [edge-tts](https://github.com/rany2/edge-tts) 合成，日语可选 `ja-JP-NanamiNeural`（女声）和 `ja-JP-KeitaNeural`（男声）。对话类课文按说话人自动轮换音色。合成刻意放在本地跑而不是放进 CI：edge-tts 是非官方接口，塞进 Actions 会让发布随时可能挂掉；本地生成好提交进仓库，CI 只做搬运。

运行 App：

```bash
cd app
flutter pub get
dart run build_runner build      # 生成 drift 数据库代码
flutter run                      # 调试
flutter build apk --release --split-per-abi
```

---

## 发布

内容源已上线：<https://alembertcn.github.io/ja/>（App 默认读这个地址）。

每次 push 到 `main` 且改动了 `content/` 或 `tools/`，[publish.yml](.github/workflows/publish.yml) 会自动校验、构建并发布到 Pages。仓库必须保持 public，否则 Pages 需要 GitHub Pro。Pages 的 Source 已经是 `GitHub Actions`（首次 `deploy-pages` 运行时自动设置的），一般不用再去 Settings 里动。

想临时换内容源（比如本地 `python -m http.server`），在 App 的「我的 → 内容源」里改，不用重新打包。

## Android 签名

`android/key.properties` 与 `upload-keystore.jks` 都不入库。换机器或重装后需要自己生成：

```bash
keytool -genkey -v -keystore app/android/upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10950 -alias upload
```

然后在 `app/android/key.properties` 写入 `storePassword` / `keyPassword` / `keyAlias=upload` / `storeFile=../upload-keystore.jks`。没有这个文件时 release 会退回 debug 签名，仍然能构建。

---

*学习资料的政策与报名细则可能变更，报考前请再核对官方页面。*
