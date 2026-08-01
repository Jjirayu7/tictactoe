APP_NAME := tictactoe
APP_PATH := $(CURDIR)/$(APP_NAME).app

.PHONY: build perf run verify clean

build:
	./build.sh

perf:
	mkdir -p .build
	swiftc -O -parse-as-library Sources/TicTacToe/AudioDeviceManager.swift Tests/AudioPerformance/main.swift -o .build/audio-performance
	.build/audio-performance

run: build
	open -n "$(APP_PATH)"

verify: build
	codesign --verify --deep --strict "$(APP_PATH)"

clean:
	rm -rf -- .build .swiftpm "$(APP_PATH)"
