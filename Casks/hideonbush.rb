cask "hideonbush" do
  version "0.1.0"
  sha256 "a8349d4db5abd2786e467af0e399037edf01fdfdbe40c3656a90c76eb1aac54a"

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
