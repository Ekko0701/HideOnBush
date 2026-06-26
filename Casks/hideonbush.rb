cask "hideonbush" do
  version "0.1.0"
  sha256 "8cc37740735b3b67e0f7a839d8c8244dc8a0ac9e05f418d0bd1fa2a7ebb65b88"

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
