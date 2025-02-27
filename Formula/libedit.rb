class Libedit < Formula
  desc "BSD-style licensed readline alternative"
  homepage "https://thrysoee.dk/editline/"
  url "https://thrysoee.dk/editline/libedit-20191211-3.1.tar.gz"
  version "20191211-3.1"
  sha256 "ea51bf76ab18073debbd0d27e4348bb11cc30cbe6ef15debcde7704b115f41d9"

  bottle do
    cellar :any
    sha256 "e73aa0d478d8f71fdf002c5adf8fc5e9ab656831aff648443f286a45ac453c42" => :catalina
    sha256 "4b6728253c28771f62018bbfd585e4c2850f8590c1084677478983783b278caa" => :mojave
    sha256 "f6b94869543ffcacaf9206dab037c6d2c64903cba213999aa67a6db2a170fc7c" => :high_sierra
    sha256 "3042d01b6030511b3629f62331885b0082238c08979c88a880642a2ecbc508fb" => :x86_64_linux
  end

  keg_only :provided_by_macos

  uses_from_macos "ncurses"

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}"
    system "make", "install"

    unless OS.mac?
      # Conflicts with ncurses.
      mv man3/"history.3", man3/"history_libedit.3"
      # Symlink libedit.so.0 to libedit.so.2 for binary compatibility with Debian/Ubuntu.
      ln_s lib/"libedit.so.0", lib/"libedit.so.2"
    end
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      #include <histedit.h>
      int main(int argc, char *argv[]) {
        EditLine *el = el_init(argv[0], stdin, stdout, stderr);
        return (el == NULL);
      }
    EOS
    system ENV.cc, "test.c", "-o", "test", "-L#{lib}", "-ledit", "-I#{include}"
    system "./test"
  end
end
