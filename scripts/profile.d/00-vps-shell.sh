# shellcheck shell=bash
# shellcheck disable=SC1113
#
# /etc/profile.d/00-vps-shell.sh
#
# Sourced automatically by /etc/profile for every interactive LOGIN shell
# (this is what `su - <user>` starts, so it fires on every new browser
# terminal connection, not just once at container boot).
#
# `install` is intentionally a shell FUNCTION here, not a script placed on
# PATH. Ubuntu ships a real `install` binary at /usr/bin/install (coreutils)
# used by build tools such as `make install`. A same-named script under
# /usr/local/bin would shadow it for every process on the system, silently
# breaking anything that shells out to `install -m 755 ...`. A non-exported
# bash function only intercepts the bare word `install` typed directly into
# THIS interactive shell; any other process (make, a script run with
# `bash file.sh`, etc.) still resolves `install` via PATH and gets the real
# coreutils binary, because non-exported functions are never inherited by
# child processes.
install() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: install <package> [<package>...]" >&2
        return 1
    fi
    sudo apt-get update && sudo apt-get install -y "$@"
}

# Show the banner + a live system snapshot once per interactive login.
case "$-" in
    *i*)
        /usr/local/lib/vps/banner.sh
        ;;
esac
