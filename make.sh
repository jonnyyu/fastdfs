tmp_src_filename=fdfs_check_bits.c
cat <<EOF > $tmp_src_filename
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
int main()
{
	printf("%d\n", (int)sizeof(long));
	printf("%d\n", (int)sizeof(off_t));
	return 0;
}
EOF

gcc -D_FILE_OFFSET_BITS=64 -o a.out $tmp_src_filename
output=$(./a.out)

if [ -f /bin/expr ]; then
  EXPR=/bin/expr
else
  EXPR=/usr/bin/expr
fi

count=0
int_bytes=4
off_bytes=8
for col in $output; do
    if [ $count -eq 0 ]; then
        int_bytes=$col
    else
        off_bytes=$col
    fi

    count=$($EXPR $count + 1)
done

/bin/rm -f a.out $tmp_src_filename
if [ "$int_bytes" -eq 8 ]; then
 OS_BITS=64
else
 OS_BITS=32
fi

if [ "$off_bytes" -eq 8 ]; then
 OFF_BITS=64
else
 OFF_BITS=32
fi

cat <<EOF > common/_os_bits.h
#ifndef _OS_BITS_H
#define _OS_BITS_H

#define OS_BITS  $OS_BITS
#define OFF_BITS $OFF_BITS

#endif
EOF

ENABLE_STATIC_LIB=0
ENABLE_SHARED_LIB=1
TARGET_PREFIX=/usr/local
TARGET_CONF_PATH=/etc/fdfs

#WITH_LINUX_SERVICE=1

DEBUG_FLAG=1

CFLAGS='-Wall -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE'
if [ "$DEBUG_FLAG" = "1" ]; then
  CFLAGS="$CFLAGS -g -O -DDEBUG_FLAG"
else
  CFLAGS="$CFLAGS -O3"
fi

LIBS=''
uname=$(uname)
if [ "$uname" = "Linux" ]; then
  CFLAGS="$CFLAGS -DOS_LINUX"
elif [ "$uname" = "FreeBSD" ]; then
  CFLAGS="$CFLAGS -DOS_FREEBSD"
elif [ "$uname" = "SunOS" ]; then
  CFLAGS="$CFLAGS -DOS_SUNOS -D_THREAD_SAFE"
  LIBS="$LIBS -lsocket -lnsl -lresolv"
  export CC=gcc
elif [ "$uname" = "AIX" ]; then
  CFLAGS="$CFLAGS -DOS_AIX -D_THREAD_SAFE"
  export CC=gcc
elif [ "$uname" = "HP-UX" ]; then
  CFLAGS="$CFLAGS -DOS_HPUX"
fi

if [ -f /usr/lib/libpthread.so ] || [ -f /usr/local/lib/libpthread.so ] || [ -f /lib64/libpthread.so ] || [ -f /usr/lib64/libpthread.so ] || [ -f /usr/lib/libpthread.a ] || [ -f /usr/local/lib/libpthread.a ] || [ -f /lib64/libpthread.a ] || [ -f /usr/lib64/libpthread.a ]; then
  LIBS="$LIBS -lpthread"
elif [ "$uname" = "HP-UX" ]; then
  lib_path="/usr/lib/hpux$OS_BITS"
  if [ -f $lib_path/libpthread.so ]; then
    LIBS="-L$lib_path -lpthread"
  fi
elif [ "$uname" = "FreeBSD" ]; then
  if [ -f /usr/lib/libc_r.so ]; then
    line=$(nm -D /usr/lib/libc_r.so | grep pthread_create | grep -w T)
    if [ $? -eq 0 ]; then
      LIBS="$LIBS -lc_r"
    fi
  elif [ -f /lib64/libc_r.so ]; then
    line=$(nm -D /lib64/libc_r.so | grep pthread_create | grep -w T)
    if [ $? -eq 0 ]; then
      LIBS="$LIBS -lc_r"
    fi
  elif [ -f /usr/lib64/libc_r.so ]; then
    line=$(nm -D /usr/lib64/libc_r.so | grep pthread_create | grep -w T)
    if [ $? -eq 0 ]; then
      LIBS="$LIBS -lc_r"
    fi
  fi
fi

TRACKER_HTTPD_OBJS=''
STORAGE_HTTPD_OBJS=''
if [ "$DEBUG_FLAG" = "1" ]; then
  TRACKER_HTTPD_OBJS="$TRACKER_HTTPD_OBJS tracker_dump.o"
  STORAGE_HTTPD_OBJS="$STORAGE_HTTPD_OBJS storage_dump.o"

  if [ "$uname" = "Linux" ]; then
    LIBS="$LIBS -ldl -rdynamic"
    TRACKER_HTTPD_OBJS="$TRACKER_HTTPD_OBJS ../common/linux_stack_trace.o"
    STORAGE_HTTPD_OBJS="$STORAGE_HTTPD_OBJS ../common/linux_stack_trace.o"
  fi
fi

cd tracker
cp Makefile.in Makefile
perl -pi -e "s#\\\$\(CFLAGS\)#$CFLAGS#g" Makefile
perl -pi -e "s#\\\$\(LIBS\)#$LIBS#g" Makefile
perl -pi -e "s#\\\$\(TARGET_PREFIX\)#$TARGET_PREFIX#g" Makefile
perl -pi -e "s#\\\$\(TRACKER_HTTPD_OBJS\)#$TRACKER_HTTPD_OBJS#g" Makefile
perl -pi -e "s#\\\$\(TARGET_CONF_PATH\)#$TARGET_CONF_PATH#g" Makefile
make $1 $2

cd ../storage
cp Makefile.in Makefile
perl -pi -e "s#\\\$\(CFLAGS\)#$CFLAGS#g" Makefile
perl -pi -e "s#\\\$\(LIBS\)#$LIBS#g" Makefile
perl -pi -e "s#\\\$\(TARGET_PREFIX\)#$TARGET_PREFIX#g" Makefile
perl -pi -e "s#\\\$\(STORAGE_HTTPD_OBJS\)#$STORAGE_HTTPD_OBJS#g" Makefile
perl -pi -e "s#\\\$\(TARGET_CONF_PATH\)#$TARGET_CONF_PATH#g" Makefile
make $1 $2

cd ../client
cp Makefile.in Makefile
perl -pi -e "s#\\\$\(CFLAGS\)#$CFLAGS#g" Makefile
perl -pi -e "s#\\\$\(LIBS\)#$LIBS#g" Makefile
perl -pi -e "s#\\\$\(TARGET_PREFIX\)#$TARGET_PREFIX#g" Makefile
perl -pi -e "s#\\\$\(TARGET_CONF_PATH\)#$TARGET_CONF_PATH#g" Makefile
perl -pi -e "s#\\\$\(ENABLE_STATIC_LIB\)#$ENABLE_STATIC_LIB#g" Makefile
perl -pi -e "s#\\\$\(ENABLE_SHARED_LIB\)#$ENABLE_SHARED_LIB#g" Makefile

cp fdfs_link_library.sh.in fdfs_link_library.sh
perl -pi -e "s#\\\$\(TARGET_PREFIX\)#$TARGET_PREFIX#g" fdfs_link_library.sh
make $1 $2

cd test
cp Makefile.in Makefile
perl -pi -e "s#\\\$\(CFLAGS\)#$CFLAGS#g" Makefile
perl -pi -e "s#\\\$\(LIBS\)#$LIBS#g" Makefile
perl -pi -e "s#\\\$\(TARGET_PREFIX\)#$TARGET_PREFIX#g" Makefile
cd ..

if [ "$1" = "install" ]; then
  cd ..
  cp -f restart.sh $TARGET_PREFIX/bin
  cp -f stop.sh $TARGET_PREFIX/bin

  if [ "$uname" = "Linux" ]; then
    if [ "$WITH_LINUX_SERVICE" = "1" ]; then
      if [ ! -d /etc/fdfs ]; then
        mkdir -p /etc/fdfs
        cp -f conf/tracker.conf /etc/fdfs/
        cp -f conf/storage.conf /etc/fdfs/
        cp -f conf/client.conf /etc/fdfs/
        cp -f conf/http.conf /etc/fdfs/
        cp -f conf/mime.types /etc/fdfs/
      fi

      cp -f init.d/fdfs_trackerd /etc/rc.d/init.d/
      cp -f init.d/fdfs_storaged /etc/rc.d/init.d/
      /sbin/chkconfig --add fdfs_trackerd 
      /sbin/chkconfig --add fdfs_storaged
    fi
  fi
fi

