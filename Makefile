PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
MANDIR  ?= $(PREFIX)/share/man
COMPDIR ?= /etc/bash_completion.d
DESTDIR ?=

SCRIPT = auto-reboot
MANPAGE = $(SCRIPT).1
COMPLETION = $(SCRIPT).bash_completion

.PHONY: all install uninstall check test help

all: help

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(SCRIPT) $(DESTDIR)$(BINDIR)/$(SCRIPT)
	install -d $(DESTDIR)$(MANDIR)/man1
	install -m 644 $(MANPAGE) $(DESTDIR)$(MANDIR)/man1/$(MANPAGE)
	install -d $(DESTDIR)$(COMPDIR)
	install -m 644 $(COMPLETION) $(DESTDIR)$(COMPDIR)/$(SCRIPT)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(SCRIPT)
	rm -f $(DESTDIR)$(MANDIR)/man1/$(MANPAGE)
	rm -f $(DESTDIR)$(COMPDIR)/$(SCRIPT)

check:
ifndef DESTDIR
	@command -v $(SCRIPT) >/dev/null 2>&1 || { echo "$(SCRIPT) not found in PATH"; exit 1; }
	@$(SCRIPT) --version
	@man -w $(SCRIPT) >/dev/null 2>&1 || { echo "manpage not found"; exit 1; }
endif

test:
	./run_tests.sh
	shellcheck -x $(SCRIPT)

help:
	@echo "Targets:"
	@echo "  install    Install $(SCRIPT), manpage, and bash completion (requires root)"
	@echo "  uninstall  Remove installed files (requires root)"
	@echo "  check      Verify installation"
	@echo "  test       Run test suite and shellcheck"
	@echo "  help       Show this help (default)"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)  BINDIR=$(BINDIR)"
	@echo "  MANDIR=$(MANDIR)  COMPDIR=$(COMPDIR)"
	@echo "  DESTDIR=$(DESTDIR)"
