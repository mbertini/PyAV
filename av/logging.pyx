from __future__ import absolute_import

cimport libav as lib

import logging


# Levels.
QUIET = lib.AV_LOG_QUIET
PANIC = lib.AV_LOG_PANIC
FATAL = lib.AV_LOG_FATAL
ERROR = lib.AV_LOG_ERROR
WARNING = lib.AV_LOG_WARNING
INFO = lib.AV_LOG_INFO
VERBOSE = lib.AV_LOG_VERBOSE
DEBUG = lib.AV_LOG_DEBUG

# Map from AV levels to logging levels.
level_map = {
    lib.AV_LOG_QUIET: 0,
    lib.AV_LOG_PANIC: 50,
    lib.AV_LOG_FATAL: 50,
    lib.AV_LOG_ERROR: 40,
    lib.AV_LOG_WARNING: 30,
    lib.AV_LOG_INFO: 20,
    lib.AV_LOG_VERBOSE: 10,
    lib.AV_LOG_DEBUG: 0,
}


def get_level():
    return lib.av_log_get_level()

def set_level(int level):
    lib.av_log_set_level(level)


cdef void log_callback(void *cls, int av_level, const char *format, lib.va_list args) with gil:

    # Make sure that the GIL exists.
    lib.PyEval_InitThreads()

    # Assume a reasonable maxlength of 1024.
    cdef bytes msg = b'\0' * 1024
    cdef int print_prefix = 1
    lib.av_log_format_line(cls, av_level, format, args, msg, 1024, &print_prefix)

    # Convert the level, and default to INFO
    cdef int py_level = level_map.get(av_level, 20)
    logging.getLogger('av').log(py_level, msg)

lib.av_log_set_callback(log_callback)


def log(int level, bytes message, *args):
    if args:
        message = message & args
    lib.av_log(NULL, level, message)



