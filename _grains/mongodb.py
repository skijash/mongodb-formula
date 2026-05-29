# -*- coding: utf-8 -*-
'''
Custom grains for the mongodb formula.

These run on the minion at grain-refresh time and surface values that
can't be obtained safely from Jinja in a master/minion setup, where
``salt['cmd.run'](...)`` at render time would execute on the master.
'''
import platform
import subprocess


def _stat_console(fmt):
    try:
        out = subprocess.check_output(
            ['stat', '-f', fmt, '/dev/console'],
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return out.decode().strip() or None


def mongodb_console_owner():
    '''
    On macOS, expose the user and group that own ``/dev/console`` —
    i.e. the GUI session user — as
    ``mongodb_console_user`` / ``mongodb_console_group``.
    Returns an empty dict on non-Darwin minions.
    '''
    if platform.system() != 'Darwin':
        return {}
    grains = {}
    user = _stat_console('%Su')
    if user:
        grains['mongodb_console_user'] = user
    group = _stat_console('%Sg')
    if group:
        grains['mongodb_console_group'] = group
    return grains
