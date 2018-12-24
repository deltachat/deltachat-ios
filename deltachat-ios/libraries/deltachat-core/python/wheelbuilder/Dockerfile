FROM quay.io/pypa/manylinux1_x86_64

# Configure ld.so/ldconfig and pkg-config
RUN echo /usr/local/lib64 > /etc/ld.so.conf.d/local.conf && \
    echo /usr/local/lib >> /etc/ld.so.conf.d/local.conf
ENV PKG_CONFIG_PATH /usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig

# Install meson and ninja
ENV NINJA_VERSION v1.8.2
ENV NINJA_SHA256 d2fea9ff33b3ef353161ed906f260d565ca55b8ca0568fa07b1d2cab90a84a07
RUN curl -L -o ninja-linux-$NINJA_VERSION.zip https://github.com/ninja-build/ninja/releases/download/${NINJA_VERSION}/ninja-linux.zip
RUN echo "${NINJA_SHA256}  ninja-linux-${NINJA_VERSION}.zip" | sha256sum -c -
RUN unzip ninja-linux-${NINJA_VERSION}.zip
RUN mv ninja /usr/bin/ninja
RUN /opt/python/cp37-cp37m/bin/pip install meson
RUN cd /usr/bin && ln -s /opt/_internal/cpython-3.7.*/bin/meson

# Install a recent zlib, needed by libetpan
ENV ZLIB_VERSION 1.2.11
ENV ZLIB_SHA256 c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1
RUN curl -O https://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz
RUN echo "${ZLIB_SHA256}  zlib-${ZLIB_VERSION}.tar.gz" | sha256sum -c -
RUN tar xzf zlib-${ZLIB_VERSION}.tar.gz
RUN cd zlib-${ZLIB_VERSION} && ./configure
RUN cd zlib-${ZLIB_VERSION} && make
RUN cd zlib-${ZLIB_VERSION} && make install
RUN ldconfig -v

# Install a recent Perl, needed to install OpenSSL
ENV PERL_VERSION 5.28.0
ENV PERL_SHA256 7e929f64d4cb0e9d1159d4a59fc89394e27fa1f7004d0836ca0d514685406ea8
RUN curl -O https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz
RUN echo "${PERL_SHA256}  perl-${PERL_VERSION}.tar.gz" | sha256sum -c -
RUN tar xzf perl-${PERL_VERSION}.tar.gz
RUN cd perl-${PERL_VERSION} && ./Configure -de
RUN cd perl-${PERL_VERSION} && make
RUN cd perl-${PERL_VERSION} && make install

# Install OpenSSL
ENV OPENSSL_VERSION 1.1.1a
ENV OPENSSL_SHA256 fc20130f8b7cbd2fb918b2f14e2f429e109c31ddd0fb38fc5d71d9ffed3f9f41
RUN curl -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
RUN echo "${OPENSSL_SHA256}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c -
RUN tar xzf openssl-${OPENSSL_VERSION}.tar.gz
RUN cd openssl-${OPENSSL_VERSION} && \
    ./config shared no-ssl2 no-ssl3 -fPIC --prefix=/usr/local
RUN cd openssl-${OPENSSL_VERSION} && \
    sed -i "s/^SHLIB_MAJOR=.*/SHLIB_MAJOR=200/" Makefile && \
    sed -i "s/^SHLIB_MINOR=.*/SHLIB_MINOR=0.0/" Makefile && \
    sed -i "s/^SHLIB_VERSION_NUMBER=.*/SHLIB_VERSION_NUMBER=200.0.0/" Makefile
RUN cd openssl-${OPENSSL_VERSION} && make depend
RUN cd openssl-${OPENSSL_VERSION} && make
RUN cd openssl-${OPENSSL_VERSION} && make install_sw install_ssldirs
RUN ldconfig -v

# Install cyrus-sasl
ENV SASL_VERSION 2.1.27
ENV SASL_SHA256 26866b1549b00ffd020f188a43c258017fa1c382b3ddadd8201536f72efb05d5
RUN curl -O ftp://ftp.cyrusimap.org/cyrus-sasl/cyrus-sasl-${SASL_VERSION}.tar.gz
RUN echo "${SASL_SHA256}  cyrus-sasl-${SASL_VERSION}.tar.gz" | sha256sum -c -
RUN tar zxf cyrus-sasl-${SASL_VERSION}.tar.gz
RUN cd cyrus-sasl-${SASL_VERSION} && \
    ./configure --disable-silent-rules \
                --disable-cmulocal \
                --disable-sample \
                --disable-obsolete_cram_attr \
                --disable-obsolete_digest_attr \
                --disable-staticdlopen \
                --disable-java \
                --disable-alwaystrue \
                --enable-checkapop \
                --enable-cram \
                --enable-digest \
                --enable-scram \
                --disable-otp \
                --disable-srp \
                --disable-srp-setpass \
                --disable-krb4 \
                --disable-gssapi \
                --disable-gss_mutexes \
                --disable-sia \
                --disable-auth-sasldb \
                --disable-httpform \
                --enable-plain \
                --enable-anon \
                --enable-login \
                --disable-ntlm \
                --disable-passdss \
                --disable-sql \
                --disable-ldapdb \
                --disable-macos-framework
RUN cd cyrus-sasl-${SASL_VERSION} && make
RUN cd cyrus-sasl-${SASL_VERSION} && make install
RUN ldconfig -v

# Install libetpan
ENV ETPAN_VERSION 1.9.1
ENV ETPAN_SHA256 f5e354ccf1014c6ee313ade1009b8a82f28043d2504655e388bb4c1328700fcd
RUN curl -L -o libetpan-${ETPAN_VERSION}.tar.gz \
    https://github.com/dinhviethoa/libetpan/archive/${ETPAN_VERSION}.tar.gz
RUN echo "${ETPAN_SHA256}  libetpan-${ETPAN_VERSION}.tar.gz" | sha256sum -c -
RUN tar xzf libetpan-${ETPAN_VERSION}.tar.gz
RUN cd libetpan-${ETPAN_VERSION} && \
    ./autogen.sh && \
    ./configure --enable-ipv6 \
                --disable-iconv --disable-db \
                --with-openssl --with-sasl --with-zlib \
                --without-curl --without-expat
RUN cd libetpan-${ETPAN_VERSION} && make
RUN cd libetpan-${ETPAN_VERSION} && make install
RUN ldconfig -v
