class Deno < Formula
  desc "Command-line JavaScript / TypeScript engine"
  homepage "https://deno.land/"
  url "https://github.com/denoland/deno/releases/download/v0.27.0/deno_src.tar.gz"
  version "0.27.0"
  sha256 "fb53009b6b3d648a30ca37f938d8c82fd1e80d0b57641789672466ac7bb1deb8"

  bottle do
    cellar :any_skip_relocation
    sha256 "af2d09092847da30ff675d8b1c9661f5bdd64e4f4dae4926025b7302ee303bf9" => :catalina
    sha256 "5a4a77868df7d6b0082b7b432d4b487120339b5cb81e63d5b8dcf126d09959a7" => :mojave
    sha256 "97c6736c1a473600105a07a87f783ca67fff9ad4bae3445bbd1e9aca5253c4df" => :high_sierra
    sha256 "69c668a68cf5a74f59799d7903a082858c850c3857852b09a0d5173623f459e6" => :x86_64_linux
  end

  depends_on "llvm" => :build if OS.linux? || DevelopmentTools.clang_build_version < 1100
  depends_on "ninja" => :build
  depends_on "rust" => :build
  unless OS.mac?
    depends_on "xz" => :build
    depends_on "python@2"
  end

  depends_on :xcode => ["10.0", :build] if OS.mac? # required by v8 7.9+

  resource "gn" do
    url "https://gn.googlesource.com/gn.git",
      :revision => "152c5144ceed9592c20f0c8fd55769646077569b"
  end

  def install
    # Build gn from source (used as a build tool here)
    (buildpath/"gn").install resource("gn")
    cd "gn" do
      system "python", "build/gen.py"
      system "ninja", "-C", "out/", "gn"
    end

    # env args for building a release build with our clang, ninja and gn
    ENV["DENO_NO_BINARY_DOWNLOAD"] = "1"
    ENV["DENO_GN_PATH"] = buildpath/"gn/out/gn"
    args = %w[
      clang_use_chrome_plugins=false
      treat_warnings_as_errors=false
    ]
    args << "mac_deployment_target=\"#{MacOS.version}\"" if OS.mac?
    if OS.linux? || DevelopmentTools.clang_build_version < 1100
      # build with llvm and link against system libc++ (no runtime dep)
      args << "clang_base_path=\"#{Formula["llvm"].prefix}\""
      ENV.remove "HOMEBREW_LIBRARY_PATHS", Formula["llvm"].opt_lib
    else # build with system clang
      args << "clang_base_path=\"/usr/\""
    end
    ENV["DENO_BUILD_ARGS"] = args.join(" ")

    unless OS.mac?
      system "core/libdeno/build/linux/sysroot_scripts/install-sysroot.py", "--arch=amd64"
    end

    cd "cli" do
      system "cargo", "install", "-vv", "--locked", "--root", prefix, "--path", "."
    end

    # Install bash and zsh completion
    output = Utils.popen_read("#{bin}/deno completions bash")
    (bash_completion/"deno").write output
    output = Utils.popen_read("#{bin}/deno completions zsh")
    (zsh_completion/"_deno").write output
  end

  test do
    (testpath/"hello.ts").write <<~EOS
      console.log("hello", "deno");
    EOS
    hello = shell_output("#{bin}/deno run hello.ts")
    assert_includes hello, "hello deno"
  end
end
