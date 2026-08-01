APP_NAME := tictactoe
APP_PATH := $(CURDIR)/$(APP_NAME).app

.PHONY: build run verify clean

build:
	./build.sh

run: build
	open -n "$(APP_PATH)"

verify: build
	codesign --verify --deep --strict "$(APP_PATH)"

clean:
	rm -rf -- .build .swiftpm "$(APP_PATH)"
