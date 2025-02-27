class Mariadb < Formula
  desc "Drop-in replacement for MySQL"
  homepage "https://mariadb.org/"
  url "https://downloads.mariadb.org/f/mariadb-10.4.10/source/mariadb-10.4.10.tar.gz"
  sha256 "cd50fddf86c2a47405737e342f78ebd40d5716f0fb32b976245de713bed01421"
  revision 1

  bottle do
    rebuild 1
    sha256 "18e0955580bab62f509fdb8d86be34067a9081bacf9f79a1effb6c1a9cfc2a38" => :catalina
    sha256 "ffa3588886d847ecfaae8806f2212446103279d2b1be99c61c17e18e0c5cd820" => :mojave
    sha256 "bf7d36b6e56a9d44991abb5f249ccaa0dcebae715262b7560fc46a5f17011cbf" => :high_sierra
    sha256 "958942697b1e237990c8c85164d2e02acc5707b7dd309dd73abcb0b696e82dba" => :x86_64_linux
  end

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "groonga"
  depends_on "openssl@1.1"
  unless OS.mac?
    depends_on "bison" => :build
    depends_on "gcc@7" => :build
    depends_on "bzip2"
    depends_on "ncurses"
    depends_on "libcsv"
    depends_on "linux-pam"
    depends_on "zlib"
  end

  conflicts_with "mysql", "percona-server",
    :because => "mariadb, mysql, and percona install the same binaries"
  conflicts_with "mytop", :because => "both install `mytop` binaries"
  conflicts_with "mariadb-connector-c",
    :because => "both install plugins"

  fails_with :gcc => "4"
  fails_with :gcc => "5"
  fails_with :gcc => "6"

  def install
    # Set basedir and ldata so that mysql_install_db can find the server
    # without needing an explicit path to be set. This can still
    # be overridden by calling --basedir= when calling.
    inreplace "scripts/mysql_install_db.sh" do |s|
      s.change_make_var! "basedir", "\"#{prefix}\""
      s.change_make_var! "ldata", "\"#{var}/mysql\""
    end

    # Use brew groonga
    rm_r "storage/mroonga/vendor/groonga"

    # -DINSTALL_* are relative to prefix
    args = %W[
      -DMYSQL_DATADIR=#{var}/mysql
      -DINSTALL_INCLUDEDIR=include/mysql
      -DINSTALL_MANDIR=share/man
      -DINSTALL_DOCDIR=share/doc/#{name}
      -DINSTALL_INFODIR=share/info
      -DINSTALL_MYSQLSHAREDIR=share/mysql
      -DWITH_PCRE=bundled
      -DWITH_READLINE=yes
      -DWITH_SSL=yes
      -DWITH_UNIT_TESTS=OFF
      -DDEFAULT_CHARSET=utf8mb4
      -DDEFAULT_COLLATION=utf8mb4_general_ci
      -DINSTALL_SYSCONFDIR=#{etc}
      -DCOMPILATION_COMMENT=Homebrew
    ]

    unless OS.mac?
      args << "-DWITH_NUMA=OFF"
      args << "-DPLUGIN_ROCKSDB=NO"
      args << "-DPLUGIN_MROONGA=NO"
    end

    # disable TokuDB, which is currently not supported on macOS
    args << "-DPLUGIN_TOKUDB=NO"

    system "cmake", ".", *std_cmake_args, *args
    system "make"
    system "make", "install"

    # Fix my.cnf to point to #{etc} instead of /etc
    (etc/"my.cnf.d").mkpath
    inreplace "#{etc}/my.cnf", "!includedir /etc/my.cnf.d",
                               "!includedir #{etc}/my.cnf.d"
    touch etc/"my.cnf.d/.homebrew_dont_prune_me"

    # Don't create databases inside of the prefix!
    # See: https://github.com/Homebrew/homebrew/issues/4975
    rm_rf prefix/"data"

    # Save space
    (prefix/"mysql-test").rmtree
    (prefix/"sql-bench").rmtree

    # Link the setup script into bin
    bin.install_symlink prefix/"scripts/mysql_install_db"

    # Fix up the control script and link into bin
    inreplace "#{prefix}/support-files/mysql.server", /^(PATH=".*)(")/, "\\1:#{HOMEBREW_PREFIX}/bin\\2"

    bin.install_symlink prefix/"support-files/mysql.server"

    # Move sourced non-executable out of bin into libexec
    libexec.install "#{bin}/wsrep_sst_common"
    # Fix up references to wsrep_sst_common
    %w[
      wsrep_sst_mysqldump
      wsrep_sst_rsync
      wsrep_sst_mariabackup
    ].each do |f|
      inreplace "#{bin}/#{f}", "$(dirname $0)/wsrep_sst_common",
                               "#{libexec}/wsrep_sst_common"
    end

    # Install my.cnf that binds to 127.0.0.1 by default
    (buildpath/"my.cnf").write <<~EOS
      # Default Homebrew MySQL server config
      [mysqld]
      # Only allow connections from localhost
      bind-address = 127.0.0.1
    EOS
    etc.install "my.cnf"
  end

  def post_install
    # https://github.com/Homebrew/linuxbrew-core/pull/16457
    # chown: changing ownership of mariadb/10.4.10_1/lib/plugin/auth_pam_tool_dir/auth_pam_tool
    # Operation not permitted
    return if ENV["CI"]

    # Make sure the var/mysql directory exists
    (var/"mysql").mkpath
    unless File.exist? "#{var}/mysql/mysql/user.frm"
      ENV["TMPDIR"] = nil
      system "#{bin}/mysql_install_db", "--verbose", "--user=#{ENV["USER"]}",
        "--basedir=#{prefix}", "--datadir=#{var}/mysql", "--tmpdir=/tmp"
    end
  end

  def caveats; <<~EOS
    A "/etc/my.cnf" from another install may interfere with a Homebrew-built
    server starting up correctly.

    MySQL is configured to only allow connections from localhost by default

    To connect:
        mysql -uroot
  EOS
  end

  plist_options :manual => "mysql.server start"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/mysqld_safe</string>
        <string>--datadir=#{var}/mysql</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>WorkingDirectory</key>
      <string>#{var}</string>
    </dict>
    </plist>
  EOS
  end

  test do
    # terminate called after throwing an instance of 'std::bad_alloc'
    return if ENV["CI"]

    system bin/"mysqld", "--version"
    prune_file = etc/"my.cnf.d/.homebrew_dont_prune_me"
    assert_predicate prune_file, :exist?, "Failed to find #{prune_file}!"
  end
end
