# shellcheck shell=bash
# shellcheck disable=SC1113
#
# /etc/profile.d/00-tra-shell.sh
#
# Sourced automatically by /etc/profile for every interactive LOGIN shell
# (this is what `su -` starts, so it fires on every new browser terminal
# connection - or, since v0.5, every new tmux window/reattach).
#
# All commands are named tra-<something>, so unlike v0.1's `install`
# there is no risk of shadowing a coreutils binary - every tra-* command
# is a plain script on PATH (see src/commands/).

# Branded prompt instead of the default user@hostname style. \w keeps the
# current directory visible (e.g. "~" at home, "~/project" elsewhere),
# which is genuinely useful and not something we're trying to hide.
PS1='[TheRealAnonymousRSA] \w\$ '

case "$-" in
    *i*)
        /opt/tra/branding/banner.sh
        ;;
esac
