
#!/usr/bin/env bash
DOWNDIR=/tmp
PREFIX=/opt/neo
wget=$PREFIX/bin/wget

err() {
    echo "Error occurred:"
    awk 'NR>L-4 && NR<L+4 { printf "%-5d%3s%s\n",NR,(NR==L?">>>":""),$0 }' L=$1 $0
}

trap 'err $LINENO' ERR


if [ "$EUID" -ne 0 ]; then
	echo "We are not running as root! Attempting to elevate privilages via sudo!"
	echo "Refusing to run without root"
    exit
fi

if type xcode-select >&- && xpath=$( xcode-select --print-path ) &&
   test -d "${xpath}" && test -x "${xpath}" ; then
   echo "We have command line tools!"
else
    echo "Command line tools aren't installed, please install command line tools"
    exit
fi

function configure_path(){
    export PATH="$PREFIX/bin:$PATH"
}

function configure_additional(){
    export LDFLAGS="-L$PREFIX/lib" export CPPFLAGS=-I$PREFIX/include
}

function configure_sys_for_debug(){
    CURRENT_SESSION=$(date '+%d-%b-%Y-%T')
    CURRRENT_SESSION_DIR=$DOWNDIR/$CURRENT_SESSION
    LOGS=$CURRRENT_SESSION_DIR/logs
    CONFIGURE=$LOGS/configure
    MAKE=$LOGS/make
    INSTALL=$LOGS/install
    ADDITIONAL_STEPS=$LOGS/additional
    mkdir $CURRRENT_SESSION_DIR
    mkdir $LOGS
    mkdir $CONFIGURE
    mkdir $MAKE
    mkdir $INSTALL
    mkdir $ADDITIONAL_STEPS
    chown -R $SUDO_USER $CURRRENT_SESSION_DIR
}

function build_indispensable(){
    current_function=(${FUNCNAME[0]})
    cd $DOWNDIR
    echo "We need some additional build tools to build DPKG"
    sleep 2
    echo "\033[1;32m==> Getting additional tool: libtool by GNU\033[0m"
    curl -Os https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.xz
    echo "\033[1;34m    ==> Unpacking additional tool: libtool by GNU\033[0m"
    tar -xzf libtool-2.4.6.tar.xz
    cd libtool-2.4.6
    echo "\033[1;34m    ==> Building additional tool: libtool by GNU\033[0m"
    ./configure --disable-dependency-tracking --prefix=$PREFIX --program-prefix=g --enable-ltdl-install &> $CONFIGURE/libtool.log
    make &> $MAKE/libtool.log
    make install &> $INSTALL/libtool.log
    echo "\033[1;34m    ==> Fixing links of the additional tool: libtool by GNU\033[0m"
    ln -s $PREFIX/bin/glibtoolize $PREFIX/bin/libtoolize &> $ADDITIONAL_STEPS/libtool.log
    cd $DOWNDIR
    echo "\033[1;32m==> Getting additional tool: autoconf\033[0m"
    curl -Os https://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz 
    echo "\033[1;34m    ==> Unpacking additional tool: autoconf\033[0m"
    tar -xzf autoconf-2.69.tar.gz 
    cd autoconf-2.69/
    echo "\033[1;34m    ==> Building additional tool: autoconf\033[0m"
    ./configure --prefix=$PREFIX &> $CONFIGURE/autoconf.log
    make &> $MAKE/autoconf.log
    make install &> $INSTALL/autoconf.log
    rm -rf $PREFIX/info/standards.info
    cd $DOWNDIR
    # We need to fix the path now, so automake can be built
    configure_path
    echo "\033[1;32m==> Getting additional tool: automake\033[0m"
    curl -Os http://ftp.vim.org/ftp/gnu/automake/automake-1.16.1.tar.gz
    echo "\033[1;34m    ==> Unpacking additional tool: automake\033[0m"
    tar -xzf automake-1.16.1.tar.gz
    cd automake-1.16.1 
    echo "\033[1;34m    ==> Building additional tool: automake\033[0m"
    ./configure --prefix=$PREFIX &> $CONFIGURE/automake.log
    make &> $MAKE/automake.log
    make install &> $INSTALL/automake.log
    cd $DOWNDIR
    configure_additional && configure_path
    echo "\033[1;32m==> Getting additional tool: openssl\033[0m"
    curl -O https://www.openssl.org/source/openssl-1.1.1f.tar.gz
    echo "\033[1;34m    ==> Unpacking additional tool: openssl\033[0m"
    tar -xzf openssl-1.1.1f.tar.gz
    cd openssl-1.1.1f
    echo "\033[1;34m    ==> Building additional tool: openssl\033[0m"
    perl ./Configure --prefix=$PREFIX --openssldir=$PREFIX/etc/openssl no-ssl3 no-ssl3-method no-zlib darwin64-x86_64-cc enable-ec_nistp_64_gcc_128 &> $CONFIGURE/openssl.log
    make &> $MAKE/openssl.log
    make test &> $ADDITIONAL_STEPS/openssl.log
    make install MANDIR=-$PREFIX/share/man MANSUFFIX=ssl &> $INSTALL/openssl.log
    echo "\033[1;34m    ==> Configuring additional tool: openssl\033[0m"
    security find-certificate -a -p /Library/Keychains/System.keychain >> $PREFIX/etc/openssl/cert.pem
    security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >> $PREFIX/etc/openssl/cert.pem
    echo "\033[1;32m==> Getting additional tool: wget\033[0m"
    curl -Os https://ftp.gnu.org/gnu/wget/wget-1.20.3.tar.gz
    tar -xzf wget-1.20.3.tar.gz
    cd wget-1.20.3
    ./configure --prefix=$PREFIX --sysconfdir=$PREFIX/etc --with-ssl=openssl --with-libssl-prefix=$PREFIX gl_cv_func_ftello_works=yes --disable-debug --disable-pcre --disable-pcre2 --without-libpsl &> $CONFIGURE/wget.log 
    make &> $MAKE/wget.log
    make install &> $INSTALL/wget.log
}

function build_pkgconfig(){ 
    cd $DOWNDIR
    echo "\033[1;32m==> Getting bootstrap tool: pkg-config\033[0m"
    $wget https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz --no-check-certificate --inet4-only
    echo "\033[1;34m    ==> Unpacking bootstrap tool: pkg-config\033[0m"
    tar -xzf pkg-config-0.29.2.tar.gz
    cd pkg-config-0.29.2
    echo "\033[1;34m    ==> Building bootstrap tool: pkg-config\033[0m"
    ./configure --disable-debug --prefix=$PREFIX --disable-host-tool --with-internal-glib &> $CONFIGURE/pkgconfig.log
    make &> $MAKE/pkgconfig.log
    make check &> $ADDITIONAL_STEPS/pkgconfig.log
    make install &> $INSTALL/pkgconfig.log
    echo "\033[1;33m==> pkg-config is built and ready to go\033[0m"
}

function build_gtar(){
    cd $DOWNDIR
    sudo -i -u $SUDO_USER bash << EOF
    cd /tmp
    echo "\033[1;32m==> Getting bootstrap tool: gtar by GNU\033[0m"
    $wget https://ftp.gnu.org/gnu/tar/tar-1.32.tar.gz --no-check-certificate --inet4-only
    echo "\033[1;34m    ==> Unpacking bootstrap tool: gtar by GNU\033[0m"
    tar -xzf tar-1.32.tar.gz
    cd tar-1.32
    # Idk if I should blame Apple for Darwin or GNU but we need gl_cv_func_ftello_works=yes as a workaround for now :/
    echo "\033[1;34m    ==> Building bootstrap tool: gtar by GNU\033[0m"
    cd /tmp/tar-1.32
    ./configure --prefix=$PREFIX --mandir=$PREFIX/share/man --program-prefix=g gl_cv_func_ftello_works=yes  &> $CONFIGURE/gtar.log
EOF
    cd /tmp/tar-1.32
    make  &> $MAKE/gtar.log
    make install &> $INSTALL/gtar.log
    echo "\033[1;33m==> gtar by GNU is built and ready to go\033[0m"
}

function build_gpatch(){
    cd $DOWNDIR
    echo "\033[1;32m==> Getting bootstrap tool: patch by GNU\033[0m"
    $wget https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz --no-check-certificate --inet4-only
    echo "\033[1;34m    ==> Unpacking bootstrap tool: patch by GNU\033[0m"
    tar -xzf patch-2.7.6.tar.xz
    cd patch-2.7.6
    echo "\033[1;34m    ==> Building bootstrap tool: patch by GNU\033[0m"
    ./configure --prefix=$PREFIX --disable-dependency-tracking &> $CONFIGURE/gpatch.log
    make &> $MAKE/gpatch.log
    make install &> $INSTALL/gpatch.log
    echo "\033[1;33m==> patch by GNU is built and ready to go\033[0m"
}

function build_perl(){
    cd $DOWNDIR
    echo "\033[1;32m==> Getting bootstrap tool: Perl\033[0m"
    $wget https://www.cpan.org/src/5.0/perl-5.30.1.tar.gz --no-check-certificate --inet4-only
    tar -xzf perl-5.30.1.tar.gz
    echo "\033[1;34m    ==> Unpacking bootstrap tool: Perl\033[0m"
    cd perl-5.30.1
    echo "\033[1;34m    ==> Building bootstrap tool: Perl\033[0m"
    # Be aware: This version of perl, is the only one that is correctly compiled for macOS and Darwin.
    # Why? When I was testing some of my software, on multiple VMs, I discovered this, when I removed the /tmp/perl
    # directory I got a "DYLD library not loaded error", as a programer, I was very curious, how to fix this error
    # I ended up in some MacPorts forums, where they talked about a very suspicious line of code http://mac-os-forge.2317878.n4.nabble.com/MacPorts-58572-perl5-28-5-28-2-build-failure-on-macOS-Catalina-td379335.html
    # I researched further into the perl source code, and the Brew package manager formulae, I then found the cause of the erorr after exploring the makefile
    # SHRPLDFLAGS variable, was set to /tmp/perl and I was also setting, the -Duseshpld flag, like brew does
    # I went into researching Apple's perl, and it isn't compiled with this option, i continue, my "duckduckgoing" until i found some
    # mailing list of perl, porters, talking about this issue, https://www.nntp.perl.org/group/perl.perl5.porters/2018/06/msg251323.html
    # turns out this option is currently deprecated, for Darwin, some options are still present here, to mimic UNIX hosts, like Debian or Ubuntu
    # Further research is required to build perl in a proper way? (idk)
    # TODO: Read more about this https://salsa.debian.org/perl-team/interpreter/perl/-/blob/debian-5.30/debian/config.debian
    ./Configure -des -Dprefix=$PREFIX -Dman1dir=$PREFIX/share/man/man1 -Dman3dir=$PREFIX/share/man/man3 -Dvendorlib=$PREFIX/share/perl5 -Dvendorprefix=$PREFIX -Dprivlib=$PREFIX/share/perl/5.30.1 -Dsitelib=$PREFIX/share/perl/5.30.1	 -Duselargefiles -Dusethreads &> $CONFIGURE/perl.log
    make &> $MAKE/perl.log
    echo "\033[1;34m    ==> Running tests for bootstrap tool: Perl (This is going to take a while)\033[0m"
    #Here I make test jobs go faster 
    #TEST_JOBS=4 make test  >> $ADDITIONAL_STEPS/perl.log
    echo "\033[1;34m    ==> Installing bootstrap tool: Perl\033[0m"
    make install &> $INSTALL/perl.log
}

function build_xz(){
    cd $DOWNDIR
    echo "\033[1;32m==> Getting bootstrap tool: xz\033[0m"
    $wget https://downloads.sourceforge.net/project/lzmautils/xz-5.2.4.tar.gz --no-check-certificate --inet4-only
    echo "\033[1;34m    ==> Unpacking bootstrap tool: xz\033[0m"
    tar -xzf xz-5.2.4.tar.gz
    echo "\033[1;34m    ==> Building bootstrap tool: xz\033[0m"
    cd xz-5.2.4
    ./configure --disable-debug --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX &> $CONFIGURE/xz.log
    make &> $MAKE/xz.log
    make check  &> $ADDITIONAL_STEPS/xz.log
    make install &> $INSTALL/xz.log
}

function build_zstd(){
    cd $DOWNDIR
    echo "\033[1;32m==> Getting bootstrap tool: zstd\033[0m"
    $wget https://github.com/facebook/zstd/archive/v1.4.4.tar.gz --no-check-certificate --inet4-only
    echo "\033[1;34m    ==> Unpacking bootstrap tool: zstd\033[0m"
    tar -xzf v1.4.4.tar.gz 
    echo "\033[1;34m    ==> Building bootstrap tool: zstd\033[0m"
    cd zstd-1.4.4
    make &> $MAKE/zstd.log
    make install PREFIX=$PREFIX &> $INSTALL/zstd.log

}

function build_dpkg(){
    cd $DOWNDIR
    echo "\033[1;32m==> Building tool: dpkg\033[0m"
    $wget http://archive.ubuntu.com/ubuntu/pool/main/d/dpkg/dpkg_1.19.7ubuntu2.tar.xz --no-check-certificate --inet4-only
    echo "\033[1;34m    ==> Unpacking tool:dpkg\033[0m"
    tar -xzf dpkg_1.19.7ubuntu2.tar.xz
    cd dpkg
    echo "\033[1;34m    ==> Building tool:dpkg\033[0m"
    configure_path
    configure_additional 
    PERL=$PREFIX/bin/perl
    POD2MAN=$PREFIX/bin/pod2man
    PERL_LIBDIR=$PREFIX/share/perl5
    PATCH=$PREFIX/bin/patch
    TAR=$PREFIX/bin/gtar
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX --sysconfdir=$PREFIX/etc --localstatedir=$PREFIX/var --disable-start-stop-daemon --with-libzstd &> $CONFIGURE/dpkg.log
    make &> $MAKE/dpkg.log
    make install &> $INSTALL/dpkg.log
}

function get_ready_for_two(){
    cd $DOWNDIR
    echo "\033[1;32m==> It's time for step two\033[0m"
    echo "\033[1;32m==> Siphinix Build: cmake\033[0m"
    # This is important:
    # During the testing of this I fould a lot of errors build cmake software
    # Turns out cmake didn't even install
    # So I looked back and the error turned out to be, sphinix
    # After some research turns out stock python conflicted with Conda. 
    # The solution for now is to not pack Sphinix until I can find a good solution
    # For this problem
    # But also, if conda exist, hand the instalation to conda if it doesn't
    # use pip3
    # TODO: Port Debian python utilities. So this error can be fixed.
    # TODO2: Start building python as it is going to be removed from future versions of macOS
    if [ -x "$(command -v conda)" ]; then
        echo "Conda is installed, handle the instalation back to conda"
        # Reference: https://github.com/conda/conda/issues/7980
        # Reference: https://stackoverflow.com/questions/34644612/conda-silently-installing-a-package
        source ~/anaconda3/etc/profile.d/conda.sh
        conda install -y sphinx
    else
        echo "Using pip3"
        pip3 install sphinx
    fi
    echo "Finished step"
    echo "\033[1;32m==> Downloading necesary tool: cmake\033[0m"
    cd $DOWNDIR
    $wget https://github.com/Kitware/CMake/releases/download/v3.17.0-rc2/cmake-3.17.0-rc2.tar.gz --no-check-certificate --inet4-only
    tar -zxf cmake-3.17.0-rc2.tar.gz
    cd cmake-3.17.0-rc2
    ./bootstrap --prefix=$PREFIX --no-system-libs --parallel=4 --datadir=/share/cmake --mandir=/share/man --docdir=/share/doc/cmake --sphinx-html --sphinx-man --system-zlib --system-bzip2 --system-curl &> $CONFIGURE/cmake.log
    make &> $MAKE/cmake.log
    make install &> $INSTALL/cmake.log
}   

# From here, I have to admit Idk what is needed and what isnt, this is in alpha
# so I am going to test some stuff and its also fun, lets see how 
# building apt goes
function build_adns(){
    cd $DOWNDIR
    $wget https://www.chiark.greenend.org.uk/~ian/adns/ftp/adns-1.5.1.tar.gz --no-check-certificate --inet4-only
    tar -xzf adns-1.5.1.tar.gz
    cd adns-1.5.1
    ./configure --prefix=$PREFIX --disable-dynamic &> $CONFIGURE/adns.log
    make &> $MAKE/adns.log
    make install &> $INSTALL/adns.log
}

function build_bison(){
    cd $DOWNDIR
    $wget https://ftp.gnu.org/gnu/bison/bison-3.5.3.tar.xz --no-check-certificate --inet4-only
    tar -xzf bison-3.5.3.tar.xz
    cd bison-3.5.3
    ./configure --disable-dependency-tracking --prefix=$PREFIX &> $CONFIGURE/bison.log
    make &> $MAKE/bison.log
    make install &> $INSTALL/bison.log
}

function build_gettext(){
    cd $DOWNDIR
    $wget https://ftpmirror.gnu.org/gettext/gettext-0.20.1.tar.xz --no-check-certificate --inet4-only
    tar -xzf gettext-0.20.1.tar.xz
    cd gettext-0.20.1
    ./configure --disable-dependency-tracking --disable-silent-rules --disable-debug --prefix=$PREFIX --with-included-gettext gl_cv_func_ftello_works=yes --with-included-glib --with-included-libcroco --with-included-libunistring --disable-java --disable-csharp --without-git --without-cvs --without-xz &> $CONFIGURE/gettext.log
    make &> $MAKE/gettext.log
    make install &> $INSTALL/gettext.log
}

function build_texinfo(){
    cd $DOWNDIR
    $wget https://ftpmirror.gnu.org/texinfo/texinfo-6.7.tar.xz --no-check-certificate --inet4-only
    tar -xzf texinfo-6.7.tar.xz
    cd texinfo-6.7
    ./configure --disable-dependency-tracking --disable-install-warnings --prefix=$PREFIX &> $CONFIGURE/textinfo.log
    make &> $MAKE/textinfo.log
    make install &> $INSTALL/textinfo.log
}

function build_coreutils(){
    cd $DOWNDIR
    $wget https://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.xz --no-check-certificate --inet4-only
    sudo chown $SUDO_USER coreutils-8.32.tar.xz
    tar -xzf coreutils-8.32.tar.xz
    sudo chown -R $SUDO_USER coreutils-8.32
    sudo -i -u $SUDO_USER<<EOF
    cd /tmp/coreutils-8.32
    ./configure --prefix=$PREFIX --program-prefix=g --without-gmp gl_cv_func_ftello_works=yes &> $CONFIGURE/coreutils.log
EOF
    cd /tmp/coreutils-8.32  
    make &> $MAKE/coreutils.log
    make install &> $INSTALL/coreutils.log
}

function build_gmp(){
    cd $DOWNDIR
    $wget https://ftp.gnu.org/gnu/gmp/gmp-6.2.0.tar.xz --no-check-certificate --inet4-only
    tar -xzf gmp-6.2.0.tar.xz
    cd gmp-6.2.0
    ./configure --prefix=$PREFIX --enable-cxx --with-pic &> $CONFIGURE/gmp.log
    make &> $MAKE/gmp.log
    make install &> $INSTALL/gmp.log
}

function build_gengeopt(){
    cd $DOWNDIR
    $wget https://ftpmirror.gnu.org/gengetopt/gengetopt-2.23.tar.xz --no-check-certificate --inet4-only
    tar -xzf gengetopt-2.23.tar.xz
    cd gengetopt-2.23
    ./configure --disable-dependency-tracking --prefix=$PREFIX --mandir=$PREFIX/share/man &> $CONFIGURE/gengetopt.log
    make &> $MAKE/gengetopt.log
    make install &> $INSTALL/gengetopt.log
}

function build_libunistring(){
    cd $DOWNDIR
    $wget https://ftpmirror.gnu.org/libunistring/libunistring-0.9.10.tar.xz --no-check-certificate --inet4-only
    tar -xzf libunistring-0.9.10.tar.xz
    cd libunistring-0.9.10
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX &> $CONFIGURE/libunistring.log
    make &> $MAKE/libunistring
    make check &> $ADDITIONAL_STEPS/libunistring.log
    make install &> $INSTALL/libunistring.log
}

function build_libidn2(){
    cd $DOWNDIR
    $wget https://ftpmirror.gnu.org/libidn/libidn2-2.3.0.tar.gz --no-check-certificate --inet4-only
    tar -xzf libidn2-2.3.0.tar.gz
    cd libidn2-2.3.0
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX --with-libintl-prefix=$PREFIX &> $CONFIGURE/libidn2.log
    make &> $MAKE/libidn2.log
    make install &> $INSTALL/libidn2.log
}

function build_libtasn1(){
    cd $DOWNDIR
    $wget https://ftpmirror.gnu.org/libtasn1/libtasn1-4.16.0.tar.gz --no-check-certificate --inet4-only
    tar -xzf libtasn1-4.16.0.tar.gz
    cd libtasn1-4.16.0
    ./configure --prefix=$PREFIX --disable-dependency-tracking --disable-silent-rules &> $CONFIGURE/libtasn1.log
    make &> $MAKE/libtasn1.log
    make install &> $INSTALL/libtasn1.log
}

function build_nettle(){
    cd $DOWNDIR
    $wget https://github.com/Quetzis/nettle-darwin/archive/nettle-3.4.1-darwin.tar.gz --no-check-certificate --inet4-only
    tar -xzf nettle-3.4.1-darwin.tar.gz
    cd nettle-darwin-nettle-3.4.1-darwin
    ./configure --disable-dependency-tracking --prefix=$PREFIX --enable-shared --with-include-path=$PREFIX/include --with-lib-path=$PREFIX/lib &> $CONFIGURE/nettle.log
    make &> $MAKE/nettle.log
    make install &> $INSTALL/nettle.log
    make check &> $ADDITIONAL_STEPS/nettle.log
}

function build_libffi(){
    cd $DOWNDIR
    $wget https://deb.debian.org/debian/pool/main/libf/libffi/libffi_3.2.1.orig.tar.gz --no-check-certificate --inet4-only
    tar -xzf libffi_3.2.1.orig.tar.gz 
    cd libffi-3.2.1
    ./configure --disable-debug --disable-dependency-tracking --prefix=$PREFIX &> $CONFIGURE/libffi.log
    make &> $MAKE/libffi.log
    make install &> $INSTALL/libffi.log
}


function build_p11(){
    cd $DOWNDIR
    $wget https://github.com/p11-glue/p11-kit/releases/download/0.23.20/p11-kit-0.23.20.tar.xz --no-check-certificate --inet4-only
    tar -xzf p11-kit-0.23.20.tar.xz
    cd p11-kit-0.23.20
    configure_additional
    export FAKED_MODE=1
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    ./configure --disable-dependency-tracking --disable-silent-rules --disable-trust-module --prefix=$PREFIX --sysconfdir=$PREFIX/etc --with-module-config=$PREFIX/etc/pkcs11/modules --without-libtasn1 &> $CONFIGURE/p11.log
    make &> $MAKE/p11.log
    make install &> $INSTALL/p11.log
}

function build_doxygen(){
    cd $DOWNDIR
    $wget https://downloads.sourceforge.net/project/doxygen/rel-1.8.17/doxygen-1.8.17.src.tar.gz --no-check-certificate --inet4-only
    tar -xzf doxygen-1.8.17.src.tar.gz
    cd doxygen-1.8.17
    mkdir build
    cd build
    cmake .. -DCMAKE_OSX_DEPLOYMENT_TARGET="10.13" &> $ADDITIONAL_STEPS/doxygen.log
    make &> $MAKE/doxygen.log
    cp -R ./bin/* $PREFIX/bin
    cp -R ../doc/*.1 $PREFIX/share/man/man1
}

function build_libevent(){
    cd $DOWNDIR
    configure_path
    $wget https://github.com/libevent/libevent/archive/release-2.1.11-stable.tar.gz --no-check-certificate --inet4-only
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    tar -xzf release-2.1.11-stable.tar.gz
    cd libevent-release-2.1.11-stable
    rm ./Doxyfile
    $wget https://raw.githubusercontent.com/DiegoMagdaleno/Additional/master/libevent/Doxyfile
    ./autogen.sh &> $ADDITIONAL_STEPS/libevent.log
    ./configure --disable-dependency-tracking --disable-debug-mode --prefix=$PREFIX &> $CONFIGURE/libevent.log
    make &> $MAKE/libevent.log
    make install &> $INSTALL/libevent.log
    make doxygen &> $ADDITIONAL_STEPS/libevent_2.log
    cp -R ./doxygen/man/man3/*.3 $PREFIX/share/man/man3/
    mkdir $PREFIX/share/doc/libevent
    cp -R ./doxygen/html/* $PREFIX/share/doc/libevent
}

function build_expat(){
    cd $DOWNDIR
    $wget https://github.com/libexpat/libexpat/releases/download/R_2_2_9/expat-2.2.9.tar.xz --no-check-certificate --inet4-only
    tar -xzf expat-2.2.9.tar.xz
    cd expat-2.2.9
    ./configure --prefix=$PREFIX --mandir=$PREFIX/share/man &> $CONFIGURE/expat.log
    make &> $MAKE/expat.log
    make install &> $INSTALL/expat.log
}
function build_unbound(){
    cd $DOWNDIR
    $wget https://nlnetlabs.nl/downloads/unbound/unbound-1.10.0.tar.gz --no-check-certificate --inet4-only
    tar -xzf unbound-1.10.0.tar.gz
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    cd unbound-1.10.0
    ./configure --prefix=$PREFIX --sysconfdir=$PREFIX/etc --enable-event-api --enable-tfo-client --enable-tfo-server --with-libevent=$PREFIX --with-ssl=$PREFIX --with-libexpat=$PREFIX &> $CONFIGURE/unbound.log
    make &> $MAKE/unbound.log
    make install  &> $INSTALL/unbound.log
    $wget https://raw.githubusercontent.com/DiegoMagdaleno/Additional/master/unbound/createuser
    chmod a+x ./createuser
    ./createuser
    cat > ./net.unbound.plist <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>net.unbound</string>
    <key>ProgramArguments</key>
    <array>
  <string>$PREFIX/sbin/unbound</string>
  <string>-d</string>
  <string>-c</string>
  <string>$PREFIX/etc/unbound/unbound.conf</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
  </dict>
</plist>
EOF
    cp ./net.unbound.plist /Library/LaunchDaemons/net.unbound.plist
    sudo launchctl load /Library/LaunchDaemons/net.unbound.plist
}

function build_gnutls(){
    cd $DOWNDIR
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    configure_additional
    configure_path
    echo $LDFLAGS
    $wget https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/gnutls-3.6.13.tar.xz --no-check-certificate --inet4-only
    tar -xzf gnutls-3.6.13.tar.xz
    cd gnutls-3.6.13
    ./configure --disable-dependency-tracking --disable-silent-rules --disable-static --prefix=$PREFIX --sysconfdir=$PREFIX/etc --with-default-trust-store-file=$PREFIX/etc/openssl/cert.pem --disable-guile --disable-heartbeat-support --with-p11-kit gl_cv_func_ftello_works=yes
    make install LDFLAGS="-L$PREFIX/lib" CPPFLAGS=-I$PREFIX/include
    mv $PREFIX/bin/certtool $PREFIX/bin/gnutls-certtool
    mv $PREFIX/share/man/man1/certtool.1 $PREFIX/share/man/man1/gnutls-certtool.1 
}

function build_libgpgerror(){
    cd $DOWNDIR
    $wget https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.37.tar.bz2 --no-check-certificate --inet4-only
    tar -jxf libgpg-error-1.37.tar.bz2
    cd libgpg-error-1.37
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX --enable-static &> $CONFIGURE/libgpgerror.log
    make &> $MAKE/libgpgerror.log
    make install &> $INSTALL/libgpgerror.log
}

function build_libassuan(){
    cd $DOWNDIR
    configure_additional
    configure_path
    $wget https://gnupg.org/ftp/gcrypt/libassuan/libassuan-2.5.3.tar.bz2 --no-check-certificate --inet4-only
    tar -jxf libassuan-2.5.3.tar.bz2
    cd libassuan-2.5.3
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX --enable-static &> $CONFIGURE/libassuan.log
    make &> $MAKE/libassuan.log
    make install &> $INSTALL/libassuan.log
}

function build_libgcrypt(){
    cd $DOWNDIR
    $wget https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.8.5.tar.bz2 --no-check-certificate --inet4-only
    tar -jxf libgcrypt-1.8.5.tar.bz2
    configure_additional
    configure_path
    cd libgcrypt-1.8.5
    ./configure --disable-dependency-tracking --disable-silent-rules --enable-static --prefix=$PREFIX --disable-asm --with-libgpg-error-prefix=$PREFIX --disable-jent-support &> $CONFIGURE/libgcrypt.log
    make &> $MAKE/libgcrypt.log
    make check &> $ADDITIONAL_STEPS/libgcrypt.log
    make install &> $INSTALL/libgcrypt.log
}

function build_libksba(){
    cd $DOWNDIR
    $wget https://www.mirrorservice.org/sites/ftp.gnupg.org/gcrypt/libksba/libksba-1.3.5.tar.bz2 --no-check-certificate --inet4-only
    configure_additional
    configure_path
    tar -jxf libksba-1.3.5.tar.bz2
    cd libksba-1.3.5
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX &> $CONFIGURE/libksba.log
    make &> $MAKE/libksba.log
    make install &> $INSTALL/libksba.log
}

function build_libusb(){
    cd $DOWNDIR
    $wget https://github.com/libusb/libusb/releases/download/v1.0.23/libusb-1.0.23.tar.bz2 --no-check-certificate --inet4-only
    tar -jxf libusb-1.0.23.tar.bz2
    cd libusb-1.0.23
    ./configure --disable-dependency-tracking --prefix=$PREFIX &> $CONFIGURE/libusb.log
    make &> $MAKE/libusb.log
    make install &> $INSTALL/libusb.log
}


function build_npth(){
    cd $DOWNDIR
    $wget https://www.mirrorservice.org/sites/ftp.gnupg.org/gcrypt/npth/npth-1.6.tar.bz2 --no-check-certificate --inet4-only
    tar -jxf npth-1.6.tar.bz2
    cd npth-1.6
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX &> $CONFIGURE/npth.log
    make &> $MAKE/npth.log
    make install &> $INSTALL/npth.log
}

function build_pinetry(){
    cd $DOWNDIR
    $wget https://www.mirrorservice.org/sites/ftp.gnupg.org/gcrypt/pinentry/pinentry-1.1.0.tar.bz2 --no-check-certificate --inet4-only
    tar -jxf pinentry-1.1.0.tar.bz2
    configure_additional
    configure_path
    cd pinentry-1.1.0
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX --disable-pinentry-fltk --disable-pinentry-gnome3 --disable-pinentry-gtk2 --disable-pinentry-qt --disable-pinentry-qt5 --disable-pinentry-tqt --enable-pinentry-tty &> $CONFIGURE/pinentry.log
    make &> $MAKE/pinentry.log
    make install &> $INSTALL/pinentry.log
}

function build_gnupg(){
    cd $DOWNDIR
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    configure_additional
    configure_path
    $wget https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.2.20.tar.bz2 --no-check-certificate --inet4-only
    tar -jxf gnupg-2.2.20.tar.bz2
    cd gnupg-2.2.20
    ./configure --disable-dependency-tracking --disable-silent-rules --prefix=$PREFIX --sbindir=$PREFIX/bin --sysconfdir=$PREFIX/etc --enable-all-tests --enable-symcryptrun --with-pinentry-pgm=$PREFIX/bin/pinentry
    make
    make check
    make install
    if [ ! -d $PREFIX/var ]; then
        mkdir $PREFIX/var/
    fi
    if [ ! -d $PREFIX/var/run ]; then
        mkdir $PREFIX/var/run
    fi
}

function build_berkeleydb(){
    cd $DOWNDIR
    $wget https://dl.bintray.com/homebrew/mirror/berkeley-db-18.1.32.tar.gz --no-check-certificate --inet4-only
    tar -xzf berkeley-db-18.1.32.tar.gz
    cd db-18.1.32
    cd build_unix
    ../dist/configure --disable-debug --prefix=$PREFIX --mandir=$PREFIX/share/man --enable-cxx --enable-compat185 --enable-sql --enable-sql_codegen --enable-dbm --enable-stl &> $CONFIGURE/berkeleydb.log
    make &> $MAKE/berkeleydb.log
    make install $INSTALL/berkeleydb.log
    mkdir $PREFIX/share/berkeleydb
    cp -R $PREFIX/docs $PREFIX/share/berkeleydb
    rm -rf $PREFIX/docs
}

function build_lz4(){
    cd $DOWNDIR
    $wget https://github.com/lz4/lz4/archive/v1.9.2.tar.gz --no-check-certificate --inet4-only
    tar -xzf v1.9.2.tar.gz
    cd lz4-1.9.2
    make &> $MAKE/lz4.log
    make install PREFIX=$PREFIX &> $INSTALL/lz4.log
}


function build_libatomic(){
    cd $DOWNDIR
    $wget https://github.com/ivmai/libatomic_ops/releases/download/v7.6.10/libatomic_ops-7.6.10.tar.gz --no-check-certificate --inet4-only
    tar -xzf libatomic_ops-7.6.10.tar.gz
    cd libatomic_ops-7.6.10
    ./configure --disable-dependency-tracking --prefix=$PREFIX &> $CONFIGURE/libatomic.log
    make &> $MAKE/libatomic.log
    make check &> $ADDITIONAL_STEPS/libatomic.log
    make install &> $INSTALL/libatomic.log
}

function build_bdwgc(){
    cd $DOWNDIR
    $wget https://github.com/ivmai/bdwgc/releases/download/v8.0.4/gc-8.0.4.tar.gz --no-check-certificate --inet4-only
    tar -xzf gc-8.0.4.tar.gz
    cd gc-8.0.4
    configure_additional
    configure_path
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    ./configure --disable-debug --disable-dependency-tracking --prefix=$PREFIX --enable-cplusplus --enable-static &> $CONFIGURE/bdwgc.log
    make &> $MAKE/bdwgc.log
    make check &> $ADDITIONAL_STEPS/bdwgc.log
    make install &> $INSTALL/bdwgc.log
}

function build_w3m(){
    cd $DOWNDIR
    # NOTICE: NORMAL VERSION IS BROKEN, WE USE DEBIAN ONE
    $wget https://github.com/tats/w3m/archive/v0.5.3+git20190105.tar.gz --no-check-certificate --inet4-only
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    configure_path
    configure_additional
    tar -xzf v0.5.3+git20190105.tar.gz
    cd w3m-0.5.3-git20190105
    ./configure --prefix=$PREFIX --disable-image --with-ssl=$PREFIX &> $CONFIGURE/w3m.log
    make &> $MAKE/w3m.log
    make install &> $INSTALL/w3m.log
}

function build_triehash(){
    cd $DOWNDIR
    $wget https://gitlab.com/Comet_Dev/tryhashdarwin/-/archive/v0.3/tryhashdarwin-v0.3.tar.gz --no-check-certificate --inet4-only
    tar -xzf tryhashdarwin-v0.3.tar.gz
    cd tryhashdarwin-v0.3
    ./install.sh --prefix=$PREFIX --with-doc
}

function build_gsed(){
    cd $DOWNDIR
    $wget https://ftpmirror.gnu.org/sed/sed-4.8.tar.xz
    tar -xzf sed-4.8.tar.xz
    cd sed-4.8
    ./configure --prefix=/usr/local --disable-dependency-tracking --program-prefix=g gl_cv_func_ftello_works=yes &> $CONFIGURE/gsed.log
    make &> $MAKE/gsed.log
    make install &> $INSTALL/gsed.log
}

function build_docbook(){
    cd $DOWNDIR
    $wget https://gitlab.com/Comet_Dev/docbookdarwinanddebian/-/archive/4.0/docbookdarwinanddebian-4.0.tar.gz
    tar -xzf docbookdarwinanddebian-4.0.tar.gz
    cd docbookdarwinanddebian-4.0
    python3 portme.py --prefix=$PREFIX
    ./install.sh --prefix=$PREFIX
}

function build_po4a(){
    cd $DOWNDIR
    $wget https://gitlab.com/Comet_Dev/po4adarwin/-/archive/po4aDarwinInitialRelease/po4adarwin-po4aDarwinInitialRelease.tar.gz
    tar -xzf po4adarwin-po4aDarwinInitialRelease.tar.gz
    cd po4adarwin-po4aDarwinInitialRelease
    chmod a+x ./install.sh
    ./install.sh --prefix=/usr/local
}


# This costed me years, of learning, of perfecting it
# today is the day. 19 of March 2020.
function build_apt(){
    cd $DOWNDIR
    $wget https://gitlab.com/Comet_Dev/apt/-/archive/2.0.0+DarwinFinal/apt-2.0.0+DarwinFinal.tar.gz
    tar -xzf apt-2.0.0+DarwinFinal.tar.gz
    cd apt-2.0.0+DarwinFinal
    cd ./darwin/scripts
    chmod a+x *
    ./missing.sh
    ./patch.sh
    cd ..
    cd ..
    mkdir ./build
    cd ./build
    export XML_CATALOG_FILES=/opt/drw/etc/xml/docbook/schema/dtd/4.5/catalog.xml
    cmake -DCMAKE_OSX_SYSROOT=macosx -DCMAKE_OSX_DEPLOYMENT_TARGET=10.10 ..
    make
    make install
}


(
    set -e
    set -o history -o histexpand
    configure_sys_for_debug
    build_indispensable
    build_pkgconfig
    build_gtar
    build_gpatch
    build_perl
    build_xz
    build_zstd
    build_dpkg
    get_ready_for_two
    build_adns
    build_bison
    build_gettext
    build_texinfo
    build_coreutils
    build_gmp
    build_gengeopt
    build_libunistring
    build_libidn2
    build_libtasn1
    build_nettle
    build_libffi
    build_p11
    build_doxygen
    build_libevent
    build_expat
    build_unbound
    build_gnutls
    build_libgpgerror
    build_libassuan
    build_libgcrypt
    build_libksba
    build_libusb
    build_npth
    build_pinetry
    build_gnupg
    build_berkeleydb
    build_lz4
    build_libatomic
    build_bdwgc
    build_w3m
    build_triehash
    build_gsed
    build_docbook
    build_po4a
   
)

if [ $? -ne 0 ]; then
    echo "There was an error in one of the program functions, all has been logged, pls report it to Diego"
    exit $?
fi
