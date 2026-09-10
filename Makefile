PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
MANDIR  ?= $(PREFIX)/share/man/man1
COMPDIR ?= /etc/bash_completion.d
SYSCONFDIR ?= /etc
DESTDIR ?=

# Directory of this Makefile (trailing slash). Anchors source paths so
# 'make install' works regardless of invoking CWD.
srcdir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

SCRIPT = auto-reboot
MANPAGE = $(SCRIPT).1
COMPLETION = $(SCRIPT).bash_completion
CONF = $(SCRIPT).conf

# /var/run/reboot-required is written by this helper, shipped in
# update-notifier-common. Without it the flag never appears and only the
# uptime threshold can trigger a reboot.
REBOOT_NOTIFIER ?= /usr/share/update-notifier/notify-reboot-required

.PHONY: all install uninstall check test help

all: help

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(srcdir)$(SCRIPT) $(DESTDIR)$(BINDIR)/$(SCRIPT)
	install -d $(DESTDIR)$(MANDIR)
	install -m 644 $(srcdir)$(MANPAGE) $(DESTDIR)$(MANDIR)/$(MANPAGE)
	install -d $(DESTDIR)$(COMPDIR)
	install -m 644 $(srcdir)$(COMPLETION) $(DESTDIR)$(COMPDIR)/$(SCRIPT)
	install -d $(DESTDIR)$(SYSCONFDIR)
	@# Site config: shipped once with defaults, never overwritten
	@test -e $(DESTDIR)$(SYSCONFDIR)/$(CONF) \
	  || install -m 644 $(srcdir)$(CONF) $(DESTDIR)$(SYSCONFDIR)/$(CONF)
ifndef DESTDIR
	@test -e $(REBOOT_NOTIFIER) || { \
	  echo "$(REBOOT_NOTIFIER) missing: installing update-notifier-common"; \
	  apt-get install -y --no-install-recommends update-notifier-common; }
endif

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(SCRIPT)
	rm -f $(DESTDIR)$(MANDIR)/$(MANPAGE)
	rm -f $(DESTDIR)$(COMPDIR)/$(SCRIPT)
	@# Site config: removed only while still identical to the shipped default
	@cmp -s $(srcdir)$(CONF) $(DESTDIR)$(SYSCONFDIR)/$(CONF) \
	  && rm -f $(DESTDIR)$(SYSCONFDIR)/$(CONF) ||:

check:
ifndef DESTDIR
	@command -v $(SCRIPT) >/dev/null 2>&1 || { echo "$(SCRIPT) not found in PATH"; exit 1; }
	@$(SCRIPT) --version
	@man -w $(SCRIPT) >/dev/null 2>&1 || { echo "manpage not found"; exit 1; }
	@test -e $(REBOOT_NOTIFIER) || { echo "$(REBOOT_NOTIFIER) not found (install update-notifier-common)"; exit 1; }
	@test -f $(SYSCONFDIR)/$(CONF) || { echo "$(SYSCONFDIR)/$(CONF) not found"; exit 1; }
endif

test:
	$(srcdir)run_tests.sh
	shellcheck -x $(srcdir)$(SCRIPT) $(srcdir)run_tests.sh $(srcdir)$(COMPLETION)
	shellcheck -x -s bash $(srcdir)tests/test_helper.bash

help:
	@echo "Targets:"
	@echo "  install    Install $(SCRIPT), manpage, completion, $(SYSCONFDIR)/$(CONF) if absent;"
	@echo "             add update-notifier-common if missing (requires root)"
	@echo "  uninstall  Remove installed files; keeps an edited $(SYSCONFDIR)/$(CONF) (requires root)"
	@echo "  check      Verify installation"
	@echo "  test       Run test suite and shellcheck"
	@echo "  help       Show this help (default)"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)  BINDIR=$(BINDIR)"
	@echo "  MANDIR=$(MANDIR)  COMPDIR=$(COMPDIR)"
	@echo "  SYSCONFDIR=$(SYSCONFDIR)"
	@echo "  DESTDIR=$(DESTDIR)"
