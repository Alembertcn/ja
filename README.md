# ja — 日语学习资料与学习 App

本仓库同时是**日语学习笔记**和**「学JA」App 的内容源**。

学习资料用 Markdown 写给人看；课文用结构化 JSON 写给 App 看。JSON 由 AI 按学习计划预先生成并提交入库，经构建脚本校验后发布到 GitHub Pages，Flutter App 直接拉取渲染，不需要任何后端服务。

---

## 目录导航

| 目录 | 内容 |
|------|------|
| [docs/exam/](docs/exam/) | JLPT 报考流程、材料、网址与注意事项 |
| [docs/plan/](docs/plan/) | 学习计划与知识点大纲（模块编号 `G2-E01` 等是 AI 生成课文的索引） |
| [docs/lessons/](docs/lessons/) | 人工整理的精讲笔记（Markdown） |
| [content/](content/) | 课文数据源（JSON），App 的内容源头 |
| [audio/](audio/) | 整篇预生成日语音频（`article.mp3` + 时间轴），由 `tools/tts.py` 产出并入库 |
| [prompts/](prompts/) | 给 AI 的固定生成模板 |
| [tools/](tools/) | 合成与构建脚本（Python），入口是 `publish.py` |
| [app/](app/) | Flutter 客户端工程 |
| `dist/` | 构建产物，不入库，由 CI 生成并发布到 Pages |

### 文档索引

- [JLPT报考指南](docs/exam/JLPT报考指南.md) — 报名、缴费、准考证、考试日、查分、领证全流程
- [N2学习计划_2027年7月](docs/plan/N2学习计划_2027年7月.md) — 42 周计划、四阶段路线、知识点大纲、AI 提示词模板
- [第一次见面_对话精讲](docs/lessons/第一次见面_对话精讲.md) — 入门对话逐句精讲与 TTS 工具推荐
- [W01_第一周_假名发音寒暄](docs/lessons/W01_第一周_假名发音寒暄.md) — 第 1 周学习资料：假名·寒暄语法·词汇·短文解析

---

## 内容是怎么流转的

```text
docs/plan/ 学习计划（模块编号）
      ↓  按 prompts/ 模板让 AI 生成
content/articles/*.json  ← 结构化课文，人工校对后提交
      ↓
      │  python tools/publish.py 一条命令跑完下面三步
      │    tts.py    逐句合成再合并为整篇 → audio/<课文 id>/article.mp3 + index.json（cues）
      │    build.py  校验 + 注入 audio/cues → dist/
      │    git       提交并推送
      ↓
GitHub Actions → GitHub Pages（公开 CDN）
      ↓  HTTPS + ETag 增量拉取
Flutter App（列表 / 整篇朗读按进度高亮 / 单句 AI讲解）
```

## 常用命令

新增一篇课文：

1. 在 Cursor 里按 [prompts/生成课文.md](prompts/生成课文.md) 指定周次与语法模块，让 AI 产出 JSON；
2. 保存到 `content/articles/<id>.json`，人工校对读音与解析。文件名必须和 JSON 里的 `id` 一致；
3. 一条命令发布：

```bash
pip install edge-tts        # 只需装一次
python tools/publish.py     # 合成音频 → 校验构建 → 提交推送
```

Actions 跑完（约一分钟）后，App 下拉刷新就能看到，**不需要重新打包 App**。

想分步或改音色时用底层脚本：

```bash
python tools/publish.py --no-push        # 只到构建，自己检查后再提交
python tools/tts.py --list-voices        # 看有哪些日语音色
python tools/tts.py --voice ja-JP-KeitaNeural --force
python tools/build.py --check            # 只校验不写文件（CI 用这条）
```

## 关于朗读

朗读只播 `audio/<id>/article.mp3` 整篇音频，用 `cues` 时间轴在播放进度上高亮当前句，不用手机系统 TTS。构建时 `tts.py` 仍按句调用 edge-tts（对话可换音色），再拼成一篇并写入句级 `startMs`/`endMs`。`build.py` 发现缺 `article.mp3` 或 cues 对不齐会直接报错。详情页可以把整篇音频下到本地，之后断网也能播。

音频用 [edge-tts](https://github.com/rany2/edge-tts) 合成，日语可选 `ja-JP-NanamiNeural`（女声）和 `ja-JP-KeitaNeural`（男声），对话类课文按说话人自动轮换。合成按「文本 + 音色 + 语速」的 hash 做增量，改一句只重合成那一句再重新合并。

合成刻意放在本地跑而不是放进 CI：edge-tts 是非官方接口，塞进 Actions 会让发布随时可能挂掉；本地生成好提交进仓库，CI 只做搬运。

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

每次 push 到 `main` 且改动了 `content/`、`audio/` 或 `tools/`，[publish.yml](.github/workflows/publish.yml) 会自动校验、构建并发布到 Pages。仓库必须保持 public，否则 Pages 需要 GitHub Pro。Pages 的 Source 已经是 `GitHub Actions`（首次 `deploy-pages` 运行时自动设置的），一般不用再去 Settings 里动。

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
