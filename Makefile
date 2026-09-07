PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
MANDIR  ?= $(PREFIX)/share/man/man1
COMPDIR ?= /etc/bash_completion.d
DESTDIR ?=

# Directory of this Makefile (trailing slash). Anchors source paths so
# 'make install' works regardless of invoking CWD.
srcdir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

SCRIPT = auto-reboot
MANPAGE = $(SCRIPT).1
COMPLETION = $(SCRIPT).bash_completion

.PHONY: all install uninstall check test help

all: help

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(srcdir)$(SCRIPT) $(DESTDIR)$(BINDIR)/$(SCRIPT)
	install -d $(DESTDIR)$(MANDIR)
	install -m 644 $(srcdir)$(MANPAGE) $(DESTDIR)$(MANDIR)/$(MANPAGE)
	install -d $(DESTDIR)$(COMPDIR)
	install -m 644 $(srcdir)$(COMPLETION) $(DESTDIR)$(COMPDIR)/$(SCRIPT)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(SCRIPT)
	rm -f $(DESTDIR)$(MANDIR)/$(MANPAGE)
	rm -f $(DESTDIR)$(COMPDIR)/$(SCRIPT)

check:
ifndef DESTDIR
	@command -v $(SCRIPT) >/dev/null 2>&1 || { echo "$(SCRIPT) not found in PATH"; exit 1; }
	@$(SCRIPT) --version
	@man -w $(SCRIPT) >/dev/null 2>&1 || { echo "manpage not found"; exit 1; }
endif

test:
	$(srcdir)run_tests.sh
	shellcheck -x $(srcdir)$(SCRIPT) $(srcdir)run_tests.sh $(srcdir)$(COMPLETION)
	shellcheck -x -s bash $(srcdir)tests/test_helper.bash

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
