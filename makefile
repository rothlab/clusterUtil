PREFIX=$(USER)/.local/bin/

install:
	cp *.sh $(PREFIX)
	bash aliases
	