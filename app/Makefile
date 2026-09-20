# JA 日语精读 · Flutter 常用命令
# 用法：cd app && make <目标>
# 一览：make help

FLUTTER ?= fvm flutter
ROOT := $(abspath ..)
# 优先用仓库根目录的 .venv（含 edge-tts / mutagen）
PYTHON := $(shell if [ -x "$(ROOT)/.venv/bin/python" ]; then echo "$(ROOT)/.venv/bin/python"; else echo python3; fi)

# 自动取第一台匹配平台的设备 ID；也可手动指定：make run DEVICE=GANNSCJJ7PVCCUFM
DEVICE_ANDROID = $(shell $(FLUTTER) devices --machine 2>/dev/null | python3 -c "import sys,json; ds=json.load(sys.stdin); print(next((d['id'] for d in ds if str(d.get('targetPlatform','')).startswith('android')), ''))")
DEVICE_IOS = $(shell $(FLUTTER) devices --machine 2>/dev/null | python3 -c "import sys,json; ds=json.load(sys.stdin); print(next((d['id'] for d in ds if str(d.get('targetPlatform','')).startswith('ios')), ''))")

.PHONY: help get run run-ios devices clean analyze test apk apk-debug install publish venv

help:
	@echo "可用命令："
	@echo "  make get        拉取依赖 (pub get)"
	@echo "  make run        调试运行 Android（默认选第一台）"
	@echo "  make run-ios    调试运行 iOS"
	@echo "  make devices    列出可用设备"
	@echo "  make analyze    静态分析"
	@echo "  make test       跑测试"
	@echo "  make apk        打 release 分包 APK"
	@echo "  make apk-debug  打 debug APK"
	@echo "  make install    安装 release 包到手机"
	@echo "  make clean      清理构建缓存"
	@echo "  make venv       创建/更新 Python 虚拟环境（发布依赖）"
	@echo "  make publish    合成音频 → 构建 → 提交推送（内容发布）"
	@echo ""
	@echo "指定设备：make run DEVICE=<id>   （id 见 make devices）"
	@echo "发布参数：make publish ARGS='--no-push'  或  ARGS='--only W01-xxx --force-audio'"

get:
	$(FLUTTER) pub get

run:
	@id="$(if $(DEVICE),$(DEVICE),$(DEVICE_ANDROID))"; \
	if [ -z "$$id" ]; then echo "未找到 Android 设备，先 make devices 检查"; exit 1; fi; \
	echo "→ $$id"; \
	$(FLUTTER) run -d "$$id" $(ARGS)

run-ios:
	@id="$(if $(DEVICE),$(DEVICE),$(DEVICE_IOS))"; \
	if [ -z "$$id" ]; then echo "未找到 iOS 设备，先 make devices 检查"; exit 1; fi; \
	echo "→ $$id"; \
	$(FLUTTER) run -d "$$id" $(ARGS)

devices:
	$(FLUTTER) devices

clean:
	$(FLUTTER) clean

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

apk:
	$(FLUTTER) build apk --release --split-per-abi

apk-debug:
	$(FLUTTER) build apk --debug

install:
	$(FLUTTER) install --release

# 内容发布：合成音频 → 校验构建 → git 提交推送（在仓库根目录跑）
venv:
	cd $(ROOT) && python3 -m venv .venv
	$(ROOT)/.venv/bin/pip install -U pip
	$(ROOT)/.venv/bin/pip install -r $(ROOT)/tools/requirements.txt
	@echo "✓ 虚拟环境就绪：$(ROOT)/.venv"

publish:
	@if [ ! -x "$(ROOT)/.venv/bin/python" ]; then \
		echo "还没有 .venv，先执行：make venv"; exit 1; \
	fi
	cd $(ROOT) && $(PYTHON) tools/publish.py $(ARGS)
