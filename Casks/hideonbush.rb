cask "hideonbush" do
  version "0.1.0"
  sha256 "d205356b083febe9030e9e02576e9ffffb95c0bc5ab546fab144d3bf18cb4f6c"

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
