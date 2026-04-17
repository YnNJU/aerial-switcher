SHELL := /bin/zsh

APP_NAME := aerial-switcher
BUILD_DIR := .build/release
EXECUTABLE := $(abspath $(BUILD_DIR)/$(APP_NAME))
LAUNCH_AGENT_LABEL := com.$(shell id -un).aerial-switcher
LAUNCH_AGENTS_DIR := $(HOME)/Library/LaunchAgents
LAUNCH_AGENT_PATH := $(LAUNCH_AGENTS_DIR)/$(LAUNCH_AGENT_LABEL).plist
TEMPLATE := aerial-switcher.plist.example
LOG_DIR := $(HOME)/Library/Logs
STDOUT_LOG := $(LOG_DIR)/$(APP_NAME).out.log
STDERR_LOG := $(LOG_DIR)/$(APP_NAME).err.log
GUI_DOMAIN := gui/$(shell id -u)
SETTINGS_FILE := .make-settings
SETTINGS_TOOL := zsh ./scripts/settings.sh
AGENT_TOOL := zsh ./scripts/agent.sh

.PHONY: help combo time default install uninstall enable disable reload

define RUN_NOW
	@$(MAKE) --no-print-directory "$(EXECUTABLE)"
	@$(SETTINGS_TOOL) "$(SETTINGS_FILE)" print
	@"$(EXECUTABLE)" auto $$($(SETTINGS_TOOL) "$(SETTINGS_FILE)" auto)
endef

define AGENT
	@$(AGENT_TOOL) $(1) "$(SETTINGS_FILE)" "$(TEMPLATE)" "$(LAUNCH_AGENT_PATH)" "$(LAUNCH_AGENT_LABEL)" "$(GUI_DOMAIN)" "$(EXECUTABLE)" "$(STDOUT_LOG)" "$(STDERR_LOG)"
endef

$(EXECUTABLE): Package.swift Sources/AerialSwitcher/main.swift
	@swift build -c release

help:
	@echo "Targets:"
	@echo "  make install        Build, install, enable, and run once"
	@echo "  make uninstall      Disable and remove the LaunchAgent plist"
	@echo "  make enable         Enable the installed LaunchAgent"
	@echo "  make disable        Disable the LaunchAgent"
	@echo "  make combo          Choose Tahoe or Sequoia combo"
	@echo "  make time           Change saved HHmm time points for the current combo"
	@echo "  make default        Reset time points"
	@echo "  make reload         Re-enable the LaunchAgent"
	@echo "  make help           Show this help"

combo:
	@$(SETTINGS_TOOL) "$(SETTINGS_FILE)" choose-combo
	$(call AGENT,sync)
	$(RUN_NOW)

time:
	@$(SETTINGS_TOOL) "$(SETTINGS_FILE)" choose-time
	$(call AGENT,sync)
	$(RUN_NOW)

default:
	@$(SETTINGS_TOOL) "$(SETTINGS_FILE)" reset-defaults
	$(call AGENT,sync)
	$(RUN_NOW)

install:
	@$(MAKE) --no-print-directory "$(EXECUTABLE)"
	$(call AGENT,install)
	$(RUN_NOW)

enable:
	$(call AGENT,enable)
	$(RUN_NOW)

disable:
	$(call AGENT,disable)

reload:
	$(call AGENT,reload)
	$(RUN_NOW)

uninstall:
	$(call AGENT,uninstall)
