project('etpan', 'c',
        version: '1.8',
        license: '3-part BSD')

pthreads = dependency('threads')
zlib = dependency('zlib', fallback: ['zlib', 'zlib_dep'])
openssl = dependency('openssl', fallback: ['openssl', 'dep'])
sqlite = dependency('sqlite3', fallback: ['sqlite', 'dep'])
sasl = dependency('libsasl2', fallback: ['cyrussasl', 'dep'])

src = [
  'src/data-types/base64.c',
  'src/data-types/carray.c',
  'src/data-types/charconv.c',
  'src/data-types/chash.c',
  'src/data-types/clist.c',
  'src/data-types/connect.c',
  'src/data-types/mail_cache_db.c',
  'src/data-types/maillock.c',
  'src/data-types/mailsasl.c',
  'src/data-types/mailsem.c',
  'src/data-types/mailstream.c',
  'src/data-types/mailstream_cancel.c',
  'src/data-types/mailstream_cfstream.c',
  'src/data-types/mailstream_compress.c',
  'src/data-types/mailstream_helper.c',
  'src/data-types/mailstream_low.c',
  'src/data-types/mailstream_socket.c',
  'src/data-types/mailstream_ssl.c',
  'src/data-types/md5.c',
  'src/data-types/mmapstring.c',
  'src/data-types/timeutils.c',
  'src/low-level/imap/acl.c',
  'src/low-level/imap/acl_parser.c',
  'src/low-level/imap/acl_sender.c',
  'src/low-level/imap/acl_types.c',
  'src/low-level/imap/annotatemore.c',
  'src/low-level/imap/annotatemore_parser.c',
  'src/low-level/imap/annotatemore_sender.c',
  'src/low-level/imap/annotatemore_types.c',
  'src/low-level/imap/condstore.c',
  'src/low-level/imap/condstore_types.c',
  'src/low-level/imap/enable.c',
  'src/low-level/imap/idle.c',
  'src/low-level/imap/mailimap.c',
  'src/low-level/imap/mailimap_compress.c',
  'src/low-level/imap/mailimap_extension.c',
  'src/low-level/imap/mailimap_helper.c',
  'src/low-level/imap/mailimap_id.c',
  'src/low-level/imap/mailimap_id_parser.c',
  'src/low-level/imap/mailimap_id_sender.c',
  'src/low-level/imap/mailimap_id_types.c',
  'src/low-level/imap/mailimap_keywords.c',
  'src/low-level/imap/mailimap_oauth2.c',
  'src/low-level/imap/mailimap_parser.c',
  'src/low-level/imap/mailimap_print.c',
  'src/low-level/imap/mailimap_sender.c',
  'src/low-level/imap/mailimap_socket.c',
  'src/low-level/imap/mailimap_sort.c',
  'src/low-level/imap/mailimap_sort_types.c',
  'src/low-level/imap/mailimap_ssl.c',
  'src/low-level/imap/mailimap_types.c',
  'src/low-level/imap/mailimap_types_helper.c',
  'src/low-level/imap/namespace.c',
  'src/low-level/imap/namespace_parser.c',
  'src/low-level/imap/namespace_sender.c',
  'src/low-level/imap/namespace_types.c',
  'src/low-level/imap/qresync.c',
  'src/low-level/imap/qresync_types.c',
  'src/low-level/imap/quota.c',
  'src/low-level/imap/quota_parser.c',
  'src/low-level/imap/quota_sender.c',
  'src/low-level/imap/quota_types.c',
  'src/low-level/imap/uidplus.c',
  'src/low-level/imap/uidplus_parser.c',
  'src/low-level/imap/uidplus_sender.c',
  'src/low-level/imap/uidplus_types.c',
  'src/low-level/imap/xgmlabels.c',
  'src/low-level/imap/xgmmsgid.c',
  'src/low-level/imap/xgmthrid.c',
  'src/low-level/imap/xlist.c',
  'src/low-level/imf/mailimf.c',
  'src/low-level/imf/mailimf_types.c',
  'src/low-level/imf/mailimf_types_helper.c',
  'src/low-level/imf/mailimf_write_file.c',
  'src/low-level/imf/mailimf_write_generic.c',
  'src/low-level/imf/mailimf_write_mem.c',
  'src/low-level/mime/mailmime.c',
  'src/low-level/mime/mailmime_content.c',
  'src/low-level/mime/mailmime_decode.c',
  'src/low-level/mime/mailmime_disposition.c',
  'src/low-level/mime/mailmime_types.c',
  'src/low-level/mime/mailmime_types_helper.c',
  'src/low-level/mime/mailmime_write_file.c',
  'src/low-level/mime/mailmime_write_generic.c',
  'src/low-level/mime/mailmime_write_mem.c',
  'src/low-level/smtp/mailsmtp.c',
  'src/low-level/smtp/mailsmtp_helper.c',
  'src/low-level/smtp/mailsmtp_oauth2.c',
  'src/low-level/smtp/mailsmtp_socket.c',
  'src/low-level/smtp/mailsmtp_ssl.c',
  'src/main/libetpan_version.c',
  'src/driver/implementation/data-message/data_message_driver.c',
  'src/driver/implementation/mime-message/mime_message_driver.c',
  'src/driver/interface/maildriver.c',
  'src/driver/interface/maildriver_tools.c',
  'src/driver/interface/maildriver_types.c',
  'src/driver/interface/maildriver_types_helper.c',
  'src/driver/interface/mailfolder.c',
  'src/driver/interface/mailmessage.c',
  'src/driver/interface/mailmessage_tools.c',
  'src/driver/interface/mailmessage_types.c',
  'src/driver/interface/mailstorage.c',
  'src/driver/interface/mailstorage_tools.c',
  'src/engine/mailprivacy.c',
  'src/engine/mailprivacy_tools.c',
]
inc = include_directories(
  'src/data-types',
  'src/low-level/feed',
  'src/low-level/imap',
  'src/low-level/imf',
  'src/low-level/mime',
  'src/low-level/nntp',
  'src/low-level/smtp',
  'src/main',
  'src/driver/implementation/data-message',
  'src/driver/interface',
  'src/driver/tools/',
  'include',
  'include/libetpan',
)

add_project_arguments('-DHAVE_CONFIG_H', language: 'c')
# add_project_arguments('-DHAVE_ICONV', language: 'c')

# We don't own this subproject, silence some warnings
cc = meson.get_compiler('c')
ccargs = cc.get_supported_arguments(
  [
    '-Wno-format-truncation',
    '-Wno-misleading-indentation',
    '-Wno-sometimes-uninitialized',
    '-Wno-unused-function',
  ]
)

if get_option('static-pic-lib')
  lib = static_library(
    'etpan', src,
    c_args: ccargs,
    pic: true,
    dependencies: [pthreads, zlib, openssl, sqlite, sasl],
    include_directories: inc,
  )
else
  if get_option('default_library') != 'static'
    error('Only --default-library=static is supported for now')
  endif
  lib = library(
    'etpan', src,
    c_args: ccargs,
    dependencies: [pthreads, zlib, openssl, sqlite, sasl],
    include_directories: inc,
  )
endif

dep = declare_dependency(
  include_directories: include_directories('include'),
  link_with: lib,
)
