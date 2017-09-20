class Glibmm < Formula
  desc "C++ interface to glib"
  homepage "https://www.gtkmm.org/"
  url "https://download.gnome.org/sources/glibmm/2.54/glibmm-2.54.1.tar.xz"
  sha256 "7cc28c732b04d70ed34f0c923543129083cfb90580ea4a2b4be5b38802bf6a4a"

  bottle do
    cellar :any
    sha256 "46ff598fd6c542432fcb474b56ad151e29f217ad588933bf350b377f51c969dd" => :high_sierra
    sha256 "91e373202e1118e3874ecc46abfcad97faf830d0cdc94f1a974272e8df669bd4" => :sierra
    sha256 "03ee806d8bad38ca85e0000c904276bae4222c01cee4f3a8188cbdef7473426a" => :el_capitan
    sha256 "63e4cde33dbe8626ec45bb82f79f975d9644198962dea4d4d2ec504ef49083ac" => :x86_64_linux
  end

  depends_on "pkg-config" => :build
  depends_on "libsigc++"
  depends_on "glib"

  needs :cxx11

  def install
    # Reduce memory usage below 4 GB for Circle CI.
    ENV["MAKEFLAGS"] = "-j6" if ENV["CIRCLECI"]

    ENV.cxx11

    # see https://bugzilla.gnome.org/show_bug.cgi?id=781947
    # Note that desktopappinfo.h is not installed on Linux
    # if these changes are made.
    inreplace "gio/giomm/Makefile.in" do |s|
      s.gsub! "OS_COCOA_TRUE", "OS_COCOA_TEMP"
      s.gsub! "OS_COCOA_FALSE", "OS_COCOA_TRUE"
      s.gsub! "OS_COCOA_TEMP", "OS_COCOA_FALSE"
    end if OS.mac?

    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    (testpath/"test.cpp").write <<-EOS.undent
      #include <glibmm.h>

      int main(int argc, char *argv[])
      {
         Glib::ustring my_string("testing");
         return 0;
      }
    EOS
    gettext = Formula["gettext"]
    glib = Formula["glib"]
    libsigcxx = Formula["libsigc++"]
    flags = %W[
      -I#{gettext.opt_include}
      -I#{glib.opt_include}/glib-2.0
      -I#{glib.opt_lib}/glib-2.0/include
      -I#{include}/glibmm-2.4
      -I#{libsigcxx.opt_include}/sigc++-2.0
      -I#{libsigcxx.opt_lib}/sigc++-2.0/include
      -I#{lib}/glibmm-2.4/include
      -L#{gettext.opt_lib}
      -L#{glib.opt_lib}
      -L#{libsigcxx.opt_lib}
      -L#{lib}
      -lglib-2.0
      -lglibmm-2.4
      -lgobject-2.0
      -lsigc-2.0
    ]
    flags << "-lintl" if OS.mac?
    system ENV.cxx, "-std=c++11", "test.cpp", "-o", "test", *flags
    system "./test"
  end
end
