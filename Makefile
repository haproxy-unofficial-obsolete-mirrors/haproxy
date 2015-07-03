# This GNU Makefile supports different OS and CPU combinations.
#
# You should use it this way :
#   [g]make TARGET=os ARCH=arch CPU=cpu USE_xxx=1 ...
#
# Valid USE_* options are the following. Most of them are automatically set by
# the TARGET, others have to be explictly specified :
#   USE_CTTPROXY         : enable CTTPROXY on Linux (needs kernel patch).
#   USE_DLMALLOC         : enable use of dlmalloc (see DLMALLOC_SRC)
#   USE_EPOLL            : enable epoll() on Linux 2.6. Automatic.
#   USE_GETSOCKNAME      : enable getsockname() on Linux 2.2. Automatic.
#   USE_KQUEUE           : enable kqueue() on BSD. Automatic.
#   USE_MY_EPOLL         : redefine epoll_* syscalls. Automatic.
#   USE_MY_SPLICE        : redefine the splice syscall if build fails without.
#   USE_NETFILTER        : enable netfilter on Linux. Automatic.
#   USE_PCRE             : enable use of libpcre for regex. Recommended.
#   USE_PCRE_JIT         : enable JIT for faster regex on libpcre >= 8.32
#   USE_POLL             : enable poll(). Automatic.
#   USE_PRIVATE_CACHE    : disable shared memory cache of ssl sessions.
#   USE_PTHREAD_PSHARED  : enable pthread process shared mutex on sslcache.
#   USE_REGPARM          : enable regparm optimization. Recommended on x86.
#   USE_STATIC_PCRE      : enable static libpcre. Recommended.
#   USE_TPROXY           : enable transparent proxy. Automatic.
#   USE_LINUX_TPROXY     : enable full transparent proxy. Automatic.
#   USE_LINUX_SPLICE     : enable kernel 2.6 splicing. Automatic.
#   USE_LIBCRYPT         : enable crypted passwords using -lcrypt
#   USE_CRYPT_H          : set it if your system requires including crypt.h
#   USE_VSYSCALL         : enable vsyscall on Linux x86, bypassing libc
#   USE_GETADDRINFO      : use getaddrinfo() to resolve IPv6 host names.
#   USE_OPENSSL          : enable use of OpenSSL. Recommended, but see below.
#   USE_FUTEX            : enable use of futex on kernel 2.6. Automatic.
#   USE_ACCEPT4          : enable use of accept4() on linux. Automatic.
#   USE_MY_ACCEPT4       : use own implemention of accept4() if glibc < 2.10.
#   USE_ZLIB             : enable zlib library support.
#   USE_CPU_AFFINITY     : enable pinning processes to CPU on Linux. Automatic.
#   USE_TFO              : enable TCP fast open. Supported on Linux >= 3.7.
#
# Options can be forced by specifying "USE_xxx=1" or can be disabled by using
# "USE_xxx=" (empty string).
#
# Variables useful for packagers :
#   CC is set to "gcc" by default and is used for compilation only.
#   LD is set to "gcc" by default and is used for linking only.
#   ARCH may be useful to force build of 32-bit binary on 64-bit systems
#   CFLAGS is automatically set for the specified CPU and may be overridden.
#   LDFLAGS is automatically set to -g and may be overridden.
#   SMALL_OPTS may be used to specify some options to shrink memory usage.
#   DEBUG may be used to set some internal debugging options.
#   ADDINC may be used to complete the include path in the form -Ipath.
#   ADDLIB may be used to complete the library list in the form -Lpath -llib.
#   DEFINE may be used to specify any additional define, which will be reported
#          by "haproxy -vv" in CFLAGS.
#   SILENT_DEFINE may be used to specify other defines which will not be
#     reported by "haproxy -vv".
#   EXTRA   is used to force building or not building some extra tools. By
#           default on Linux 2.6+, it contains "haproxy-systemd-wrapper".
#   DESTDIR is not set by default and is used for installation only.
#           It might be useful to set DESTDIR if you want to install haproxy
#           in a sandbox.
#   PREFIX  is set to "/usr/local" by default and is used for installation only.
#   SBINDIR is set to "$(PREFIX)/sbin" by default and is used for installation
#           only.
#   MANDIR  is set to "$(PREFIX)/share/man" by default and is used for
#           installation only.
#   DOCDIR  is set to "$(PREFIX)/doc/haproxy" by default and is used for
#           installation only.
#
# Other variables :
#   DLMALLOC_SRC   : build with dlmalloc, indicate the location of dlmalloc.c.
#   DLMALLOC_THRES : should match PAGE_SIZE on every platform (default: 4096).
#   PCREDIR        : force the path to libpcre.
#   PCRE_LIB       : force the lib path to libpcre (defaults to $PCREDIR/lib).
#   PCRE_INC       : force the include path to libpcre ($PCREDIR/inc)
#   SSL_LIB        : force the lib path to libssl/libcrypto
#   SSL_INC        : force the include path to libssl/libcrypto
#   IGNOREGIT      : ignore GIT commit versions if set.
#   VERSION        : force haproxy version reporting.
#   SUBVERS        : add a sub-version (eg: platform, model, ...).
#   VERDATE        : force haproxy's release date.

#### Installation options.
DESTDIR =
PREFIX = /usr/local
SBINDIR = $(PREFIX)/sbin
MANDIR = $(PREFIX)/share/man
DOCDIR = $(PREFIX)/doc/haproxy

#### TARGET system
# Use TARGET=<target_name> to optimize for a specifc target OS among the
# following list (use the default "generic" if uncertain) :
#    generic, linux22, linux24, linux24e, linux26, solaris,
#    freebsd, openbsd, cygwin, custom, aix51, aix52
TARGET =

#### TARGET CPU
# Use CPU=<cpu_name> to optimize for a particular CPU, among the following
# list :
#    generic, native, i586, i686, ultrasparc, custom
CPU = generic

#### Architecture, used when not building for native architecture
# Use ARCH=<arch_name> to force build for a specific architecture. Known
# architectures will lead to "-m32" or "-m64" being added to CFLAGS and
# LDFLAGS. This can be required to build 32-bit binaries on 64-bit targets.
# Currently, only 32, 64, x86_64, i386, i486, i586 and i686 are understood.
ARCH =

#### Toolchain options.
# GCC is normally used both for compiling and linking.
CC = gcc
LD = $(CC)

#### Debug flags (typically "-g").
# Those flags only feed CFLAGS so it is not mandatory to use this form.
DEBUG_CFLAGS = -g

#### Compiler-specific flags that may be used to disable some negative over-
# optimization or to silence some warnings. -fno-strict-aliasing is needed with
# gcc >= 4.4.
SPEC_CFLAGS = -fno-strict-aliasing

#### Memory usage tuning
# If small memory footprint is required, you can reduce the buffer size. There
# are 2 buffers per concurrent session, so 16 kB buffers will eat 32 MB memory
# with 1000 concurrent sessions. Putting it slightly lower than a page size
# will prevent the additional parameters to go beyond a page. 8030 bytes is
# exactly 5.5 TCP segments of 1460 bytes and is generally good. Useful tuning
# macros include :
#    SYSTEM_MAXCONN, BUFSIZE, MAXREWRITE, REQURI_LEN, CAPTURE_LEN.
# Example: SMALL_OPTS = -DBUFSIZE=8030 -DMAXREWRITE=1030 -DSYSTEM_MAXCONN=1024
SMALL_OPTS =

#### Debug settings
# You can enable debugging on specific code parts by setting DEBUG=-DDEBUG_xxx.
# Currently defined DEBUG macros include DEBUG_FULL, DEBUG_MEMORY, DEBUG_FSM,
# DEBUG_HASH and DEBUG_AUTH. Please check sources for exact meaning or do not
# use at all.
DEBUG =

#### Trace options
# Use TRACE=1 to trace function calls to file "trace.out" or to stderr if not
# possible.
TRACE =

#### Additional include and library dirs
# Redefine this if you want to add some special PATH to include/libs
ADDINC =
ADDLIB =

#### Specific macro definitions
# Use DEFINE=-Dxxx to set any tunable macro. Anything declared here will appear
# in the build options reported by "haproxy -vv". Use SILENT_DEFINE if you do
# not want to pollute the report with complex defines.
# The following settings might be of interest when SSL is enabled :
#   LISTEN_DEFAULT_CIPHERS is a cipher suite string used to set the default SSL
#           ciphers on "bind" lines instead of using OpenSSL's defaults.
#   CONNECT_DEFAULT_CIPHERS is a cipher suite string used to set the default
#           SSL ciphers on "server" lines instead of using OpenSSL's defaults.
DEFINE =
SILENT_DEFINE =

#### extra programs to build (eg: haproxy-systemd-wrapper)
# Force this to enable building extra programs or to disable them.
# It's automatically appended depending on the targets.
EXTRA =

#### CPU dependant optimizations
# Some CFLAGS are set by default depending on the target CPU. Those flags only
# feed CPU_CFLAGS, which in turn feed CFLAGS, so it is not mandatory to use
# them. You should not have to change these options. Better use CPU_CFLAGS or
# even CFLAGS instead.
CPU_CFLAGS.generic    = -O2
CPU_CFLAGS.native     = -O2 -march=native
CPU_CFLAGS.i586       = -O2 -march=i586
CPU_CFLAGS.i686       = -O2 -march=i686
CPU_CFLAGS.ultrasparc = -O6 -mcpu=v9 -mtune=ultrasparc
CPU_CFLAGS            = $(CPU_CFLAGS.$(CPU))

#### ARCH dependant flags, may be overriden by CPU flags
ARCH_FLAGS.32     = -m32
ARCH_FLAGS.64     = -m64
ARCH_FLAGS.i386   = -m32 -march=i386
ARCH_FLAGS.i486   = -m32 -march=i486
ARCH_FLAGS.i586   = -m32 -march=i586
ARCH_FLAGS.i686   = -m32 -march=i686
ARCH_FLAGS.x86_64 = -m64 -march=x86-64
ARCH_FLAGS        = $(ARCH_FLAGS.$(ARCH))

#### Common CFLAGS
# These CFLAGS contain general optimization options, CPU-specific optimizations
# and debug flags. They may be overridden by some distributions which prefer to
# set all of them at once instead of playing with the CPU and DEBUG variables.
CFLAGS = $(ARCH_FLAGS) $(CPU_CFLAGS) $(DEBUG_CFLAGS) $(SPEC_CFLAGS)

#### Common LDFLAGS
# These LDFLAGS are used as the first "ld" options, regardless of any library
# path or any other option. They may be changed to add any linker-specific
# option at the beginning of the ld command line.
LDFLAGS = $(ARCH_FLAGS) -g

#### Target system options
# Depending on the target platform, some options are set, as well as some
# CFLAGS and LDFLAGS. The USE_* values are set to "implicit" so that they are
# not reported in the build options string. You should not have to change
# anything there. poll() is always supported, unless explicitly disabled by
# passing USE_POLL="" on the make command line.
USE_POLL   = default

ifeq ($(TARGET),generic)
  # generic system target has nothing specific
  USE_POLL   = implicit
  USE_TPROXY = implicit
else
ifeq ($(TARGET),linux22)
  # This is for Linux 2.2
  USE_GETSOCKNAME = implicit
  USE_POLL        = implicit
  USE_TPROXY      = implicit
  USE_LIBCRYPT    = implicit
else
ifeq ($(TARGET),linux24)
  # This is for standard Linux 2.4 with netfilter but without epoll()
  USE_GETSOCKNAME = implicit
  USE_NETFILTER   = implicit
  USE_POLL        = implicit
  USE_TPROXY      = implicit
  USE_LIBCRYPT    = implicit
else
ifeq ($(TARGET),linux24e)
  # This is for enhanced Linux 2.4 with netfilter and epoll() patch > 0.21
  USE_GETSOCKNAME = implicit
  USE_NETFILTER   = implicit
  USE_POLL        = implicit
  USE_EPOLL       = implicit
  USE_MY_EPOLL    = implicit
  USE_TPROXY      = implicit
  USE_LIBCRYPT    = implicit
else
ifeq ($(TARGET),linux26)
  # This is for standard Linux 2.6 with netfilter and standard epoll()
  USE_GETSOCKNAME = implicit
  USE_NETFILTER   = implicit
  USE_POLL        = implicit
  USE_EPOLL       = implicit
  USE_TPROXY      = implicit
  USE_LIBCRYPT    = implicit
  USE_FUTEX       = implicit
  EXTRA          += haproxy-systemd-wrapper
else
ifeq ($(TARGET),linux2628)
  # This is for standard Linux >= 2.6.28 with netfilter, epoll, tproxy and splice
  USE_GETSOCKNAME = implicit
  USE_NETFILTER   = implicit
  USE_POLL        = implicit
  USE_EPOLL       = implicit
  USE_TPROXY      = implicit
  USE_LIBCRYPT    = implicit
  USE_LINUX_SPLICE= implicit
  USE_LINUX_TPROXY= implicit
  USE_ACCEPT4     = implicit
  USE_FUTEX       = implicit
  USE_CPU_AFFINITY= implicit
  ASSUME_SPLICE_WORKS= implicit
  EXTRA          += haproxy-systemd-wrapper
else
ifeq ($(TARGET),solaris)
  # This is for Solaris 8
  # We also enable getaddrinfo() which works since solaris 8.
  USE_POLL       = implicit
  TARGET_CFLAGS  = -fomit-frame-pointer -DFD_SETSIZE=65536 -D_REENTRANT
  TARGET_LDFLAGS = -lnsl -lsocket
  USE_TPROXY     = implicit
  USE_LIBCRYPT    = implicit
  USE_CRYPT_H     = implicit
  USE_GETADDRINFO = implicit
else
ifeq ($(TARGET),freebsd)
  # This is for FreeBSD
  USE_POLL       = implicit
  USE_KQUEUE     = implicit
  USE_TPROXY     = implicit
  USE_LIBCRYPT   = implicit
else
ifeq ($(TARGET),osx)
  # This is for Mac OS/X
  USE_POLL       = implicit
  USE_KQUEUE     = implicit
  USE_TPROXY     = implicit
  USE_LIBCRYPT   = implicit
else
ifeq ($(TARGET),openbsd)
  # This is for OpenBSD >= 3.0
  USE_POLL       = implicit
  USE_KQUEUE     = implicit
  USE_TPROXY     = implicit
else
ifeq ($(TARGET),aix51)
  # This is for AIX 5.1
  USE_POLL        = implicit
  USE_LIBCRYPT    = implicit
  TARGET_CFLAGS   = -Dss_family=__ss_family
  DEBUG_CFLAGS    =
else
ifeq ($(TARGET),aix52)
  # This is for AIX 5.2 and later
  USE_POLL        = implicit
  USE_LIBCRYPT    = implicit
  TARGET_CFLAGS   = -D_MSGQSUPPORT
  DEBUG_CFLAGS    =
else
ifeq ($(TARGET),cygwin)
  # This is for Cygwin
  # Cygwin adds IPv6 support only in version 1.7 (in beta right now). 
  USE_POLL   = implicit
  USE_TPROXY = implicit
  TARGET_CFLAGS  = $(if $(filter 1.5.%, $(shell uname -r)), -DUSE_IPV6 -DAF_INET6=23 -DINET6_ADDRSTRLEN=46, )
endif # cygwin
endif # aix52
endif # aix51
endif # openbsd
endif # osx
endif # freebsd
endif # solaris
endif # linux2628
endif # linux26
endif # linux24e
endif # linux24
endif # linux22
endif # generic


#### Old-style REGEX library settings for compatibility with previous setups.
# It is still possible to use REGEX=<regex_lib> to select an alternative regex
# library. By default, we use libc's regex. On Solaris 8/Sparc, grouping seems
# to be broken using libc, so consider using pcre instead. Supported values are
# "libc", "pcre", and "static-pcre". Use of this method is deprecated in favor
# of "USE_PCRE" and "USE_STATIC_PCRE" (see build options below).
REGEX = libc

ifeq ($(REGEX),pcre)
USE_PCRE = 1
$(warning WARNING! use of "REGEX=pcre" is deprecated, consider using "USE_PCRE=1" instead.)
endif

ifeq ($(REGEX),static-pcre)
USE_STATIC_PCRE = 1
$(warning WARNING! use of "REGEX=pcre-static" is deprecated, consider using "USE_STATIC_PCRE=1" instead.)
endif

#### Old-style TPROXY settings
ifneq ($(findstring -DTPROXY,$(DEFINE)),)
USE_TPROXY = 1
$(warning WARNING! use of "DEFINE=-DTPROXY" is deprecated, consider using "USE_TPROXY=1" instead.)
endif


#### Determine version, sub-version and release date.
# If GIT is found, and IGNOREGIT is not set, VERSION, SUBVERS and VERDATE are
# extracted from the last commit. Otherwise, use the contents of the files
# holding the same names in the current directory.

ifeq ($(IGNOREGIT),)
VERSION := $(shell [ -d .git/. ] && ref=`(git describe --tags --match 'v*' --abbrev=0) 2>/dev/null` && ref=$${ref%-g*} && echo "$${ref\#v}")
ifneq ($(VERSION),)
# OK git is there and works.
SUBVERS := $(shell comms=`git log --format=oneline --no-merges v$(VERSION).. 2>/dev/null | wc -l | tr -dc '0-9'`; [ $$comms -gt 0 ] && echo "-$$comms")
VERDATE := $(shell git log -1 --pretty=format:%ci | cut -f1 -d' ' | tr '-' '/')
endif
endif

# Last commit version not found, take it from the files.
ifeq ($(VERSION),)
VERSION := $(shell cat VERSION 2>/dev/null || touch VERSION)
endif
ifeq ($(SUBVERS),)
SUBVERS := $(shell (grep -v '\$$Format' SUBVERS 2>/dev/null || touch SUBVERS) | head -n 1)
endif
ifeq ($(VERDATE),)
VERDATE := $(shell (grep -v '^\$$Format' VERDATE 2>/dev/null || touch VERDATE) | head -n 1 | cut -f1 -d' ' | tr '-' '/')
endif

#### Build options
# Do not change these ones, enable USE_* variables instead.
OPTIONS_CFLAGS  =
OPTIONS_LDFLAGS =
OPTIONS_OBJS    =

# This variable collects all USE_* values except those set to "implicit". This
# is used to report a list of all flags which were used to build this version.
# Do not assign anything to it.
BUILD_OPTIONS =

# Return USE_xxx=$(USE_xxx) unless $(USE_xxx) = "implicit"
# Usage: 
#   BUILD_OPTIONS += $(call ignore_implicit,USE_xxx)
ignore_implicit = $(patsubst %=implicit,,$(1)=$($(1)))

ifneq ($(USE_TCPSPLICE),)
$(error experimental option USE_TCPSPLICE has been removed, check USE_LINUX_SPLICE)
endif

ifneq ($(USE_LINUX_SPLICE),)
OPTIONS_CFLAGS += -DCONFIG_HAP_LINUX_SPLICE
BUILD_OPTIONS  += $(call ignore_implicit,USE_LINUX_SPLICE)
endif

ifneq ($(USE_CTTPROXY),)
OPTIONS_CFLAGS += -DCONFIG_HAP_CTTPROXY
OPTIONS_OBJS   += src/cttproxy.o
BUILD_OPTIONS  += $(call ignore_implicit,USE_CTTPROXY)
endif

ifneq ($(USE_TPROXY),)
OPTIONS_CFLAGS += -DTPROXY
BUILD_OPTIONS  += $(call ignore_implicit,USE_TPROXY)
endif

ifneq ($(USE_LINUX_TPROXY),)
OPTIONS_CFLAGS += -DCONFIG_HAP_LINUX_TPROXY
BUILD_OPTIONS  += $(call ignore_implicit,USE_LINUX_TPROXY)
endif

ifneq ($(USE_LIBCRYPT),)
OPTIONS_CFLAGS  += -DCONFIG_HAP_CRYPT
BUILD_OPTIONS   += $(call ignore_implicit,USE_LIBCRYPT)
OPTIONS_LDFLAGS += -lcrypt
endif

ifneq ($(USE_CRYPT_H),)
OPTIONS_CFLAGS  += -DNEED_CRYPT_H
BUILD_OPTIONS   += $(call ignore_implicit,USE_CRYPT_H)
endif

ifneq ($(USE_GETADDRINFO),)
OPTIONS_CFLAGS  += -DUSE_GETADDRINFO
BUILD_OPTIONS   += $(call ignore_implicit,USE_GETADDRINFO)
endif

ifneq ($(USE_ZLIB),)
# Use ZLIB_INC and ZLIB_LIB to force path to zlib.h and libz.{a,so} if needed.
ZLIB_INC =
ZLIB_LIB =
OPTIONS_CFLAGS  += -DUSE_ZLIB $(if $(ZLIB_INC),-I$(ZLIB_INC))
BUILD_OPTIONS   += $(call ignore_implicit,USE_ZLIB)
OPTIONS_LDFLAGS += $(if $(ZLIB_LIB),-L$(ZLIB_LIB)) -lz
endif

ifneq ($(USE_POLL),)
OPTIONS_CFLAGS += -DENABLE_POLL
OPTIONS_OBJS   += src/ev_poll.o
BUILD_OPTIONS  += $(call ignore_implicit,USE_POLL)
endif

ifneq ($(USE_EPOLL),)
OPTIONS_CFLAGS += -DENABLE_EPOLL
OPTIONS_OBJS   += src/ev_epoll.o
BUILD_OPTIONS  += $(call ignore_implicit,USE_EPOLL)
endif

ifneq ($(USE_MY_EPOLL),)
OPTIONS_CFLAGS += -DUSE_MY_EPOLL
BUILD_OPTIONS  += $(call ignore_implicit,USE_MY_EPOLL)
endif

ifneq ($(USE_KQUEUE),)
OPTIONS_CFLAGS += -DENABLE_KQUEUE
OPTIONS_OBJS   += src/ev_kqueue.o
BUILD_OPTIONS  += $(call ignore_implicit,USE_KQUEUE)
endif

ifneq ($(USE_VSYSCALL),)
OPTIONS_OBJS   += src/i386-linux-vsys.o
OPTIONS_CFLAGS += -DCONFIG_HAP_LINUX_VSYSCALL
BUILD_OPTIONS  += $(call ignore_implicit,USE_VSYSCALL)
endif

ifneq ($(USE_CPU_AFFINITY),)
OPTIONS_CFLAGS += -DUSE_CPU_AFFINITY
BUILD_OPTIONS  += $(call ignore_implicit,USE_CPU_AFFINITY)
endif

ifneq ($(USE_MY_SPLICE),)
OPTIONS_CFLAGS += -DUSE_MY_SPLICE
BUILD_OPTIONS  += $(call ignore_implicit,USE_MY_SPLICE)
endif

ifneq ($(ASSUME_SPLICE_WORKS),)
OPTIONS_CFLAGS += -DASSUME_SPLICE_WORKS
BUILD_OPTIONS  += $(call ignore_implicit,ASSUME_SPLICE_WORKS)
endif

ifneq ($(USE_ACCEPT4),)
OPTIONS_CFLAGS += -DUSE_ACCEPT4
BUILD_OPTIONS  += $(call ignore_implicit,USE_ACCEPT4)
endif

ifneq ($(USE_MY_ACCEPT4),)
OPTIONS_CFLAGS += -DUSE_MY_ACCEPT4
BUILD_OPTIONS  += $(call ignore_implicit,USE_MY_ACCEPT4)
endif

ifneq ($(USE_NETFILTER),)
OPTIONS_CFLAGS += -DNETFILTER
BUILD_OPTIONS  += $(call ignore_implicit,USE_NETFILTER)
endif

ifneq ($(USE_GETSOCKNAME),)
OPTIONS_CFLAGS += -DUSE_GETSOCKNAME
BUILD_OPTIONS  += $(call ignore_implicit,USE_GETSOCKNAME)
endif

ifneq ($(USE_REGPARM),)
OPTIONS_CFLAGS += -DCONFIG_REGPARM=3
BUILD_OPTIONS  += $(call ignore_implicit,USE_REGPARM)
endif

# report DLMALLOC_SRC only if explicitly specified
ifneq ($(DLMALLOC_SRC),)
BUILD_OPTIONS += DLMALLOC_SRC=$(DLMALLOC_SRC)
endif

ifneq ($(USE_DLMALLOC),)
BUILD_OPTIONS  += $(call ignore_implicit,USE_DLMALLOC)
ifeq ($(DLMALLOC_SRC),)
DLMALLOC_SRC=src/dlmalloc.c
endif
endif

ifneq ($(DLMALLOC_SRC),)
# DLMALLOC_THRES may be changed to match PAGE_SIZE on every platform
DLMALLOC_THRES = 4096
OPTIONS_OBJS  += src/dlmalloc.o
endif

ifneq ($(USE_OPENSSL),)
# OpenSSL is packaged in various forms and with various dependences.
# In general -lssl is enough, but on some platforms, -lcrypto may be needed,
# reason why it's added by default. Some even need -lz, then you'll need to
# pass it in the "ADDLIB" variable if needed. If your SSL libraries are not
# in the usual path, use SSL_INC=/path/to/inc and SSL_LIB=/path/to/lib.
BUILD_OPTIONS   += $(call ignore_implicit,USE_OPENSSL)
OPTIONS_CFLAGS  += -DUSE_OPENSSL $(if $(SSL_INC),-I$(SSL_INC))
OPTIONS_LDFLAGS += $(if $(SSL_LIB),-L$(SSL_LIB)) -lssl -lcrypto
OPTIONS_OBJS  += src/ssl_sock.o src/shctx.o
ifneq ($(USE_PRIVATE_CACHE),)
OPTIONS_CFLAGS  += -DUSE_PRIVATE_CACHE
else
ifneq ($(USE_PTHREAD_PSHARED),)
OPTIONS_CFLAGS  += -DUSE_PTHREAD_PSHARED
OPTIONS_LDFLAGS += -lpthread
else
ifneq ($(USE_FUTEX),)
OPTIONS_CFLAGS  += -DUSE_SYSCALL_FUTEX
endif
endif
endif
endif

ifneq ($(USE_PCRE)$(USE_STATIC_PCRE)$(USE_PCRE_JIT),)
# PCREDIR is used to automatically construct the PCRE_INC and PCRE_LIB paths,
# by appending /include and /lib respectively. If your system does not use the
# same sub-directories, simply force these variables instead of PCREDIR. It is
# automatically detected but can be forced if required (for cross-compiling).
# Forcing PCREDIR to an empty string will let the compiler use the default
# locations.

PCREDIR	        := $(shell pcre-config --prefix 2>/dev/null || echo /usr/local)
ifneq ($(PCREDIR),)
PCRE_INC        := $(PCREDIR)/include
PCRE_LIB        := $(PCREDIR)/lib
endif

ifeq ($(USE_STATIC_PCRE),)
# dynamic PCRE
OPTIONS_CFLAGS  += -DUSE_PCRE $(if $(PCRE_INC),-I$(PCRE_INC))
OPTIONS_LDFLAGS += $(if $(PCRE_LIB),-L$(PCRE_LIB)) -lpcreposix -lpcre
BUILD_OPTIONS   += $(call ignore_implicit,USE_PCRE)
else
# static PCRE
OPTIONS_CFLAGS  += -DUSE_PCRE $(if $(PCRE_INC),-I$(PCRE_INC))
OPTIONS_LDFLAGS += $(if $(PCRE_LIB),-L$(PCRE_LIB)) -Wl,-Bstatic -lpcreposix -lpcre -Wl,-Bdynamic
BUILD_OPTIONS   += $(call ignore_implicit,USE_STATIC_PCRE)
endif
# JIT PCRE
ifneq ($(USE_PCRE_JIT),)
OPTIONS_CFLAGS  += -DUSE_PCRE_JIT
BUILD_OPTIONS   += $(call ignore_implicit,USE_PCRE_JIT)
endif
endif

# TCP Fast Open
ifneq ($(USE_TFO),)
OPTIONS_CFLAGS  += -DUSE_TFO
BUILD_OPTIONS   += $(call ignore_implicit,USE_TFO)
endif

# This one can be changed to look for ebtree files in an external directory
EBTREE_DIR := ebtree

#### Global compile options
VERBOSE_CFLAGS = $(CFLAGS) $(TARGET_CFLAGS) $(SMALL_OPTS) $(DEFINE)
COPTS  = -Iinclude -I$(EBTREE_DIR) -Wall
COPTS += $(CFLAGS) $(TARGET_CFLAGS) $(SMALL_OPTS) $(DEFINE) $(SILENT_DEFINE)
COPTS += $(DEBUG) $(OPTIONS_CFLAGS) $(ADDINC)

ifneq ($(VERSION)$(SUBVERS),)
COPTS += -DCONFIG_HAPROXY_VERSION=\"$(VERSION)$(SUBVERS)\"
endif

ifneq ($(VERDATE),)
COPTS += -DCONFIG_HAPROXY_DATE=\"$(VERDATE)\"
endif

ifneq ($(TRACE),)
# if tracing is enabled, we want it to be as fast as possible
TRACE_COPTS := $(filter-out -O0 -O1 -O2 -pg -finstrument-functions,$(COPTS)) -O3 -fomit-frame-pointer
COPTS += -finstrument-functions
endif

#### Global link options
# These options are added at the end of the "ld" command line. Use LDFLAGS to
# add options at the beginning of the "ld" command line if needed.
LDOPTS = $(TARGET_LDFLAGS) $(OPTIONS_LDFLAGS) $(ADDLIB)

ifeq ($(TARGET),)
all:
	@echo
	@echo "Due to too many reports of suboptimized setups, building without"
	@echo "specifying the target is no longer supported. Please specify the"
	@echo "target OS in the TARGET variable, in the following form:"
	@echo
	@echo "   $ make TARGET=xxx"
	@echo
	@echo "Please choose the target among the following supported list :"
	@echo
	@echo "   linux2628, linux26, linux24, linux24e, linux22, solaris"
	@echo "   freebsd, openbsd, cygwin, custom, generic"
	@echo
	@echo "Use \"generic\" if you don't want any optimization, \"custom\" if you"
	@echo "want to precisely tweak every option, or choose the target which"
	@echo "matches your OS the most in order to gain the maximum performance"
	@echo "out of it. Please check the Makefile in case of doubts."
	@echo
	@exit 1
else
all: haproxy $(EXTRA)
endif

OBJS = src/haproxy.o src/sessionhash.o src/base64.o src/protocol.o \
       src/uri_auth.o src/standard.o src/buffer.o src/log.o src/task.o \
       src/chunk.o src/channel.o src/listener.o \
       src/time.o src/fd.o src/pipe.o src/regex.o src/cfgparse.o src/server.o \
       src/checks.o src/queue.o src/frontend.o src/proxy.o src/peers.o \
       src/arg.o src/stick_table.o src/proto_uxst.o src/connection.o \
       src/proto_http.o src/raw_sock.o src/appsession.o src/backend.o \
       src/lb_chash.o src/lb_fwlc.o src/lb_fwrr.o src/lb_map.o src/lb_fas.o \
       src/stream_interface.o src/dumpstats.o src/proto_tcp.o \
       src/session.o src/hdr_idx.o src/ev_select.o src/signal.o \
       src/acl.o src/sample.o src/memory.o src/freq_ctr.o src/auth.o \
       src/compression.o src/payload.o src/hash.o src/pattern.o src/map.o

EBTREE_OBJS = $(EBTREE_DIR)/ebtree.o \
              $(EBTREE_DIR)/eb32tree.o $(EBTREE_DIR)/eb64tree.o \
              $(EBTREE_DIR)/ebmbtree.o $(EBTREE_DIR)/ebsttree.o \
              $(EBTREE_DIR)/ebimtree.o $(EBTREE_DIR)/ebistree.o

ifneq ($(TRACE),)
OBJS += src/trace.o
endif

WRAPPER_OBJS = src/haproxy-systemd-wrapper.o

# Not used right now
LIB_EBTREE = $(EBTREE_DIR)/libebtree.a

haproxy: $(OBJS) $(OPTIONS_OBJS) $(EBTREE_OBJS)
	$(LD) $(LDFLAGS) -o $@ $^ $(LDOPTS)

haproxy-systemd-wrapper: $(WRAPPER_OBJS)
	$(LD) $(LDFLAGS) -o $@ $^ $(LDOPTS)

$(LIB_EBTREE): $(EBTREE_OBJS)
	$(AR) rv $@ $^

objsize: haproxy
	@objdump -t $^|grep ' g '|grep -F '.text'|awk '{print $$5 FS $$6}'|sort

%.o:	%.c
	$(CC) $(COPTS) -c -o $@ $<

src/trace.o: src/trace.c
	$(CC) $(TRACE_COPTS) -c -o $@ $<

src/haproxy.o:	src/haproxy.c
	$(CC) $(COPTS) \
	      -DBUILD_TARGET='"$(strip $(TARGET))"' \
	      -DBUILD_ARCH='"$(strip $(ARCH))"' \
	      -DBUILD_CPU='"$(strip $(CPU))"' \
	      -DBUILD_CC='"$(strip $(CC))"' \
	      -DBUILD_CFLAGS='"$(strip $(VERBOSE_CFLAGS))"' \
	      -DBUILD_OPTIONS='"$(strip $(BUILD_OPTIONS))"' \
	       -c -o $@ $<

src/haproxy-systemd-wrapper.o:	src/haproxy-systemd-wrapper.c
	$(CC) $(COPTS) \
	      -DSBINDIR='"$(strip $(SBINDIR))"' \
	       -c -o $@ $<

src/dlmalloc.o: $(DLMALLOC_SRC)
	$(CC) $(COPTS) -DDEFAULT_MMAP_THRESHOLD=$(DLMALLOC_THRES) -c -o $@ $<

install-man:
	install -d "$(DESTDIR)$(MANDIR)"/man1
	install -m 644 doc/haproxy.1 "$(DESTDIR)$(MANDIR)"/man1

install-doc:
	install -d "$(DESTDIR)$(DOCDIR)"
	for x in configuration architecture haproxy-en haproxy-fr; do \
		install -m 644 doc/$$x.txt "$(DESTDIR)$(DOCDIR)" ; \
	done

install-bin: haproxy haproxy-systemd-wrapper
	install -d "$(DESTDIR)$(SBINDIR)"
	install haproxy "$(DESTDIR)$(SBINDIR)"
	install haproxy-systemd-wrapper "$(DESTDIR)$(SBINDIR)"

install: install-bin install-man install-doc

clean:
	rm -f *.[oas] src/*.[oas] ebtree/*.[oas] haproxy test
	for dir in . src include/* doc ebtree; do rm -f $$dir/*~ $$dir/*.rej $$dir/core; done
	rm -f haproxy-$(VERSION).tar.gz haproxy-$(VERSION)$(SUBVERS).tar.gz
	rm -f haproxy-$(VERSION) haproxy-$(VERSION)$(SUBVERS) nohup.out gmon.out
	rm -f haproxy-systemd-wrapper

tags:
	find src include \( -name '*.c' -o -name '*.h' \) -print0 | \
	   xargs -0 etags --declarations --members

cscope:
	find src include -name "*.[ch]" -print | cscope -q -b -i -

tar:	clean
	ln -s . haproxy-$(VERSION)$(SUBVERS)
	tar --exclude=haproxy-$(VERSION)$(SUBVERS)/.git \
	    --exclude=haproxy-$(VERSION)$(SUBVERS)/haproxy-$(VERSION)$(SUBVERS) \
	    --exclude=haproxy-$(VERSION)$(SUBVERS)/haproxy-$(VERSION)$(SUBVERS).tar.gz \
	    -cf - haproxy-$(VERSION)$(SUBVERS)/* | gzip -c9 >haproxy-$(VERSION)$(SUBVERS).tar.gz
	rm -f haproxy-$(VERSION)$(SUBVERS)

git-tar:
	git archive --format=tar --prefix="haproxy-$(VERSION)$(SUBVERS)/" HEAD | gzip -9 > haproxy-$(VERSION)$(SUBVERS).tar.gz

version:
	@echo "VERSION: $(VERSION)"
	@echo "SUBVERS: $(SUBVERS)"
	@echo "VERDATE: $(VERDATE)"

# never use this one if you don't know what it is used for.
update-version:
	@echo "Ready to update the following versions :"
	@echo "VERSION: $(VERSION)"
	@echo "SUBVERS: $(SUBVERS)"
	@echo "VERDATE: $(VERDATE)"
	@echo "Press [ENTER] to continue or Ctrl-C to abort now.";read
	echo "$(VERSION)" > VERSION
	echo "$(SUBVERS)" > SUBVERS
	echo "$(VERDATE)" > VERDATE
