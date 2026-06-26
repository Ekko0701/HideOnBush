cask "hideonbush" do
  version "0.1.1"
  sha256 "1e9bf68ca128c2793c6b7d2eb58c2160f2ec6a8708c2fd94a5ef92d2c2f7071b"

  url "https://github.com/Ekko0701/HideOnBush/releases/download/v#{version}/HideOnBush-v#{version}-macos-arm64.zip",
      verified: "github.com/Ekko0701/HideOnBush/"
  name "HideOnBush"
  desc "Menu bar switcher for approved Claude OTel Work and Personal modes"
  homepage "https://github.com/Ekko0701/HideOnBush"

  depends_on macos: :ventura

  app "HideOnBush.app"

  zap trash: [
    "~/Library/Application Support/HideOnBush",
  ]
end
