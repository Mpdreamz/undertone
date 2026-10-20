# TEMPLATE: the Homebrew cask, as scripts/bump-tap.sh writes it to mpdreamz/homebrew-tap on every release, with the
# version and the zip's sha256 filled in. Change it here, not in the tap. (bump-tap.sh replaces this header.)
cask "undertone" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/mpdreamz/undertone/releases/download/v#{version}/Undertone-arm64.zip"
  name "Undertone"
  desc "Hide the notch under generated wallpapers that follow your theme"
  homepage "https://github.com/mpdreamz/undertone"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Undertone updates itself (Sparkle); brew upgrade leaves it to that (brew upgrade --greedy still upgrades it).
  auto_updates true

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "Undertone.app"
  binary "#{appdir}/Undertone.app/Contents/Helpers/undertone"

  uninstall quit: "io.github.mpdreamz.undertone"

  zap trash: [
    "~/Library/Application Support/Undertone",
    "~/Library/Caches/io.github.mpdreamz.undertone",
    "~/Library/HTTPStorages/io.github.mpdreamz.undertone",
    "~/Library/Preferences/io.github.mpdreamz.undertone.plist",
  ]
end
