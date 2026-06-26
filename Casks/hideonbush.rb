cask "hideonbush" do
  version "0.1.0"
  sha256 "cc534cdcf6e80284217f950a23652abd0b4f255deb3d13cf6ab141316e76f668"

  url "https://github.com/Ekko0701/HideOnBush/releases/download/v#{version}/HideOnBush-v#{version}-macos-arm64.zip",
      verified: "github.com/Ekko0701/HideOnBush/"
  name "HideOnBush"
  desc "Menu bar switcher for approved Claude OTel Work and Personal modes"
  homepage "https://github.com/Ekko0701/HideOnBush"

  depends_on macos: :ventura

  app "HideOnBush.app"

  caveats do
    <<~EOS
      HideOnBush is currently distributed without Apple notarization.
      If macOS blocks it on first launch, run:

        xattr -dr com.apple.quarantine /Applications/HideOnBush.app

      Then open HideOnBush again.
    EOS
  end

  zap trash: [
    "~/Library/Application Support/HideOnBush",
  ]
end
