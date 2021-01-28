all: demo

.PHONY: demo
demo:
	go run ./examples/demo/main.go

.PHONY: emulator
emulator: 
	flow emulator start -v 
