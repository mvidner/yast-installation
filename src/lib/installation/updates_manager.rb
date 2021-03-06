# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "pathname"
require "installation/driver_update"

module Installation
  # This class takes care of managing installer updates
  #
  # Installer updates are distributed as Driver Update Disks that are downloaded
  # from a remote location (only HTTP and HTTPS are supported at this time).
  # This class tries to offer a really simple API to get updates and apply them
  # to inst-sys.
  #
  # @example Applying one driver update
  #   manager = UpdatesManager.new(Pathname.new("/update"), Pathname.new("/install.gpg"),
  #                                Pathname.new("/root/.gnupg"))
  #   manager.add_update(URI("http://update.opensuse.org/sles12.dud"))
  #   manager.add_update(URI("http://example.net/example.dud"))
  #   manager.apply_all
  #
  # @example Applying multiple driver updates
  #   manager = UpdatesManager.new(Pathname.new("/update"), Pathname.new("/install.gpg"),
  #                                Pathname.new("/root/.gnupg"))
  #   manager.add_update(URI("http://update.opensuse.org/sles12.dud"))
  #   manager.apply_all
  class UpdatesManager
    include Yast::Logger

    attr_reader :target, :keyring, :gpg_homedir, :updates

    # Constructor
    #
    # @param target      [Pathname] Directory to copy updates to.
    # @param keyring     [Pathname] Path to keyring to check signatures against
    # @param gpg_homedir [Pathname] Path to GPG home dir
    def initialize(target, keyring, gpg_homedir)
      @target = target
      @keyring = keyring
      @gpg_homedir = gpg_homedir
      @updates = []
    end

    # Add an update to the updates pool
    #
    # @param uri [URI]                               URI where the update (DUD) lives
    # @return    [Array<Installation::DriverUpdate>] List of updates
    #
    # @see Installation::DriverUpdate
    def add_update(uri)
      new_update = Installation::DriverUpdate.new(uri, keyring, gpg_homedir)
      dir = target.join(format("%03d", next_update))
      log.info("Fetching Driver update from #{uri} to #{dir}")
      new_update.fetch(dir)
      log.info("Driver update extracted to #{dir}")
      @updates << new_update
    rescue Installation::DriverUpdate::NotFound
      log.error("Driver updated at #{uri} could not be found")
      false
    end

    # Applies all updates in the pool
    def apply_all
      updates.each(&:apply)
    end

    # Determines whether the updates to apply are signed
    def all_signed?
      updates.all?(&:signed?)
    end

  private

    # Find the number for the next update to be deployed
    def next_update
      files = Pathname.glob(target.join("*")).map(&:basename)
      updates = files.map(&:to_s).grep(/\A\d+\Z/)
      updates.empty? ? 0 : updates.map(&:to_i).max + 1
    end
  end
end
