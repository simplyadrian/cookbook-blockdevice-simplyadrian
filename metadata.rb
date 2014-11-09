name             'blockdevice-nativex'
maintainer       'NativeX'
maintainer_email 'adrian.herrera@nativex.com'
license          'All rights reserved'
description      'Installs/Configures blockdevice-nativex'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends  "aws"
depends  "xfs"
depends  "ohai-nativex"