#!/usr/bin/env brew ruby
#
# Copyright (c) 2009-present, Homebrew contributors. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause
#
# Simplified version of `generate-cask-api` and `generate-cask`
#
# REF: https://github.com/Homebrew/formulae.brew.sh/blob/998358b5d3d4e8710696e841d8fb195cebedd8dd/script/generate-cask.rb
# REF: https://github.com/Homebrew/brew/blob/4d0deeb68e488fd2208c8a1058c506e70b182a63/Library/Homebrew/dev-cmd/generate-cask-api.rb#L47-L63
#

require "cask/cask"

tap_name = ARGV.first
tap = Tap.fetch(tap_name)

Cask::Cask.generating_hash!

# Homebrew 7.0.13+ stopped accepting paths in `Cask::CaskLoader.load` (it now
# returns a null loader for anything that is not a plain cask name, which made
# every cask here fail). `from_tap_path` is the supported API for loading a
# registered tap source file, and it still enforces tap trust.
load_cask = if Cask::CaskLoader.respond_to?(:from_tap_path)
  ->(path) { Cask::CaskLoader.from_tap_path(path) }
else
  ->(path) { Cask::CaskLoader.load(path) }
end

latest_macos = MacOSVersion.new(HOMEBREW_MACOS_NEWEST_SUPPORTED).to_sym
default_arch = :intel  # NOTE: Change this to :arm if you want arm as default arch.
generated = 0
failed = 0
Homebrew::SimulateSystem.with(os: latest_macos, arch: default_arch) do
  tap.cask_files.each do |path|
    cask = load_cask.call(path)
    name = cask.token
    json = JSON.pretty_generate(cask.to_hash_with_variations)

    IO.write("_data/cask/#{name}.json", "#{json}\n")
    generated += 1
  rescue => e
    failed += 1
    warn "Error while generating data for '#{path.stem}': #{e.message}"
  end
end

# Writing nothing instead of reporting a problem produces an empty cask.json,
# which silently breaks every consumer of this repository.
if generated.zero? && failed.positive?
  abort "No casks were generated for '#{tap_name}' (#{failed} failed). " \
        "Check that the tap is installed and trusted: https://docs.brew.sh/Tap-Trust"
end

warn "Generated #{generated} casks for '#{tap_name}'."

