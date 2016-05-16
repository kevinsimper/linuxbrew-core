class CAres < Formula
  desc "Asynchronous DNS library"
  homepage "http://c-ares.haxx.se/"
  url "http://c-ares.haxx.se/download/c-ares-1.11.0.tar.gz"
  mirror "https://launchpad.net/ubuntu/+archive/primary/+files/c-ares_1.11.0.orig.tar.gz"
  sha256 "b3612e6617d9682928a1d50c1040de4db6519f977f0b25d40cf1b632900b3efd"

  bottle do
    cellar :any
    sha256 "68d6374d5665448f947c8cfb2090171c0c865e239a786139f108979138d03a68" => :el_capitan
    sha256 "759c64eb8eb50bb4358c13b8ca5a7091156a1dd7a2b97784a641702ae27da2cc" => :yosemite
    sha256 "d1619087a66468b5615f630cc9ae09bf666efaf9f7085890f0a951a6359f4bd2" => :mavericks
    sha256 "7e3f3e15e8bf502da0f0acc4d57bf296553df15d5fe8f305e6b2adb94ece6c67" => :mountain_lion
  end

  head do
    url "https://github.com/bagder/c-ares.git"

    depends_on "automake" => :build
    depends_on "autoconf" => :build
    depends_on "libtool" => :build
  end

  def install
    system "./buildconf" if build.head?
    system "./configure", "--prefix=#{prefix}",
                          "--disable-dependency-tracking",
                          "--disable-debug"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <stdio.h>
      #include <ares.h>

      int main()
      {
        ares_library_init(ARES_LIB_INIT_ALL);
        ares_library_cleanup();
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-L#{lib}", "-lcares", "-o", "test"
    system "./test"
  end
end
