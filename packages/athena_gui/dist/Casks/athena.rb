cask "athena" do
  version "3.4.4"
  sha256 "21677d30dcda47575f500dc9eb6da6564093df8fcd778feda8fa711aae042692"
  url "https://github.com/CalsRanna/athena/releases/download/v3.4.4/Athena-macOS.zip"
  name "Athena"
  desc "Cross-platform AI Agent app (Flutter) with a full agent loop, built-in tools, self-evolving skills, and a strict permission model."
  homepage "https://github.com/CalsRanna/athena"

  app "Athena.app"

  zap trash: [
    "~/Library/Application Support/Athena",
  ]
end
