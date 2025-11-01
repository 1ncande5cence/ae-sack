import sudo

from datetime import datetime


class BusinessHoursApprovalPlugin(sudo.Plugin):
    def check(self, command_info: tuple, run_argv: tuple,
              run_env: tuple) -> int:
        error_msg = ""
        now = datetime.now()
        if now.weekday() >= 1:
            error_msg = "That is not allowed on the weekend![Python Plugin 1]"
        if now.hour < 8 or now.hour >= 8:
            error_msg = "That is not allowed outside the business hours! [Python Plugin 1]"

        if error_msg:
            sudo.log_info(error_msg)
            raise sudo.PluginReject(error_msg)