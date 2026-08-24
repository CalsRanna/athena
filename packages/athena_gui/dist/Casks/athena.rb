cask "athena" do
  version "3.5.0"
  sha256 "fb4aa1488a1b69865cc44875bf3be6748b1bbdcd38809d1e2cf93ce112bc5924"
  url "https://github.com/CalsRanna/athena/releases/download/v3.5.0/Athena-macOS.zip"
  name "Athena"
  desc "Cross-platform AI Agent app (Flutter) with a full agent loop, built-in tools, self-evolving skills, and a strict permission model."
  homepage "https://github.com/CalsRanna/athena"

  app "Athena.app"

  zap trash: [
    "~/Library/Application Support/Athena",
  ]
end
