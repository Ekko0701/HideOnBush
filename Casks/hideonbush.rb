cask "hideonbush" do
  version "0.1.2"
  sha256 "c5117a9a114e20915f717ba409cea7bc84d369fd4d1ac5352080bffc34ab9c27"

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
