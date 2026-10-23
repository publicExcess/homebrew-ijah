class Ijah < Formula
  desc "Raw-Metal inference engine for Qwen3.8-Flash-Next and Swift-1.5 on Apple M5"
  homepage "https://github.com/publicExcess/ijah"
  url "https://github.com/publicExcess/ijah/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "1660e6c512df1bc61c260b9a8a6df5ed293fb41ad1abed1be58c726ea40ad937"
  license "Apache-2.0"
  head "https://github.com/publicExcess/ijah.git", branch: "main"

  depends_on xcode: :build # the Metal compiler and the Metal toolchain component
  depends_on arch: :arm64
  depends_on macos: :golden_gate # macOS 27: Metal 4 tensor units
  depends_on "python@3.11"

  def m5?
    Utils.safe_popen_read("/usr/sbin/sysctl", "-n", "machdep.cpu.brand_string").split.include?("M5")
  end

  def install
    unless m5?
      odie <<~EOS
        Ijah needs an Apple M5 GPU (Metal 4 tensor units); M1 to M4 do not work.
        This Mac: #{Utils.safe_popen_read("/usr/sbin/sysctl", "-n", "machdep.cpu.brand_string").strip}
      EOS
    end
    unless quiet_system "xcrun", "-sdk", "macosx", "metal", "--version"
      odie <<~EOS
        The Metal toolchain is missing. Install Xcode, then run:
          xcodebuild -downloadComponent MetalToolchain
      EOS
    end

    system "make"
    rm_r %w[build/obj build/air] # intermediate objects; the shim build below needs only the headers and the library
    libexec.install Dir["*"]
    # the server's snapshot shim (prefix reuse across restarts), built against this library
    cd(libexec) { system "/bin/zsh", "tools/serve.sh", "build" }
    py = formula_opt_bin("python@3.11")/"python3.11"
    # The CLI is stdlib only and runs on python@3.11. The server's venv (requirements.txt) lives in var, outside the
    # keg: Homebrew rewrites the load paths of every Mach-O file in a keg, which breaks the dylibs pip wheels ship.
    # It is made on the first `ijah serve` / `ijah doctor`, and rebuilt when requirements.txt changes.
    (bin/"ijah").write <<~SH
      #!/bin/bash
      V="#{var}/ijah/venv"
      R="#{opt_libexec}/requirements.txt"
      case "$1" in serve|doctor)
        if [ ! -x "$V/bin/python" ] || ! cmp -s "$R" "$V/requirements.txt"; then
          echo "ijah: setting up the server's Python environment in $V (a minute or two, once)" >&2
          rm -rf "$V" && "#{py}" -m venv "$V" && "$V/bin/python" -m pip install -q --upgrade pip &&
            "$V/bin/python" -m pip install -q -r "$R" && cp "$R" "$V/requirements.txt" || { rm -rf "$V"; exit 1; }
        fi ;;
      esac
      export IJAH_PY="$V/bin/python"
      exec "#{py}" "#{opt_libexec}/tools/ijah" "$@"
    SH
    bin.install_symlink libexec/"build/engine-cli"
    lib.install_symlink libexec/"build/libengine.dylib", libexec/"build/engine.metallib"
  end

  def caveats
    <<~EOS
      The model files are not part of the formula. Download them (into ~/.cache/ijah), then check and start:
        ijah download base drafter ngram   # ~83 GB pack + 1.2 GB DFlash2 drafter + 102 GB n-gram table
        ijah doctor
        ijah serve start                   # or, at login: brew services start ijah

      The T6 pack (`base`) is the preferred one. `base-4bit` (~67 GB) is faster with lower fidelity.
      Swift-1.5 (non-commercial licence): ijah download swift && ijah link
      The server listens on 127.0.0.1:8140; its API key is ~/.config/ijah/api-key (made on the first start).
    EOS
  end

  service do
    run [opt_bin/"ijah", "serve", "run"]
    keep_alive crashed: true
    log_path var/"log/ijah.log"
    error_log_path var/"log/ijah.log"
  end

  test do
    assert_match "ijah serve", shell_output("#{bin}/ijah --help")
    assert_match "--revision", shell_output("#{bin}/ijah download base --dry-run")
    assert_path_exists libexec/"build/libengine.dylib"
    assert_path_exists libexec/"build/engine.metallib"
  end
end
