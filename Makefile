VERSION ?= 1.0.0
APP     := build/Strokey.app
DEST    := /Applications/Strokey.app

.PHONY: build install run dist icon clean

## 编译 build/Strokey.app
build:
	VERSION=$(VERSION) scripts/build.sh

## 编译并安装到 /Applications，然后启动
install: build
	-pkill -x Strokey
	rm -rf "$(DEST)"
	cp -R "$(APP)" "$(DEST)"
	open "$(DEST)"

## 不安装，直接运行编译结果
run: build
	-pkill -x Strokey
	open "$(APP)"

## 打包发布用的 zip：dist/Strokey-<版本>.zip
dist: build
	mkdir -p dist
	cd build && ditto -c -k --keepParent Strokey.app ../dist/Strokey-$(VERSION).zip
	@echo "✓ dist/Strokey-$(VERSION).zip"

## 重新生成图标
icon:
	scripts/make_icon.sh

clean:
	rm -rf build dist
