# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# Module:	installation.ycp
#
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# Purpose:	Visual speeding-up the installation.
#		This client only initializes the UI
#		and calls the real installation.
#
# $Id$
module Yast
  class InstallationClient < Client
    def main
      # FIXME: start the debugger only when required
      # FIXME: catch loading error, the debugger is optional (might not be present)
      start_debugger

      textdomain "installation"

      Yast.import "Wizard"
      Yast.import "Stage"
      Yast.import "Report"
      Yast.import "Hooks"

      Hooks.search_path.join!("installation")

      # Initialize the UI
      UI.SetProductLogo(true)
      Wizard.OpenLeftTitleNextBackDialog
      Wizard.SetContents(
        # title
        "",
        # contents
        Empty(),
        # help
        "",
        # has back
        false,
        # has next
        false
      )
      Wizard.SetTitleIcon("yast-inst-mode")
      Wizard.DisableAbortButton

      @ret = nil

      # Call the real installation
      Builtins.y2milestone("=== installation ===")

      Hooks.run "installation_start"

      # First-stage (initial installation)
      if Stage.initial
        Builtins.y2milestone(
          "Stage::initial -> running inst_worker_initial client"
        )
        @ret = WFM.CallFunction("inst_worker_initial", WFM.Args)

        # Second-stage (initial installation)
      elsif Stage.cont
        Builtins.y2milestone(
          "Stage::cont -> running inst_worker_continue client"
        )
        @ret = WFM.CallFunction("inst_worker_continue", WFM.Args)
      else
        # TRANSLATORS: error message
        Report.Error(_("No workflow defined for this kind of installation."))
      end

      Hooks.run "installation_failure" if @ret == false

      Builtins.y2milestone("Installation ret: %1", @ret)
      Builtins.y2milestone("=== installation ===")

      Hooks.run "installation_finish"

      # Shutdown the UI
      Wizard.CloseDialog

      WFM.CallFunction("disintegrate_all_extensions") if Stage.initial

      deep_copy(@ret)
    end

    private

    def start_debugger
      require "byebug"
      Byebug.wait_connection = false
      Byebug.start_server("localhost", 3344)

      # start the debugger when receiving the SIGUSR1 signal
      # TODO: is it safe to start it from a signal handler?
      # TODO: does it collide with the SIGUSR1 handling yast2-core
      # (toggling the debug logging)
      Signal.trap("USR1") do
        job = fork do
            # FIXME: remove the hardcoded version (fix the alternative in inst-sys?)
            # FIXME: this works only in the Qt UI
            exec "xterm", "-e", "byebug.ruby2.1-3.5.1", "-R", "localhost:3344"
        end
        Process.detach(job)

        # wait a bit for the byebug client to start
        sleep(2)

        # start the debugger
        byebug
      end
    end
  end
end
