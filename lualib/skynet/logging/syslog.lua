local logging = require("skynet.logging.logging")

function logging.syslog(ident, facility)
    local lsyslog = require 'lsyslog'

    local convert = {
        [logging.DEBUG] = lsyslog.LEVEL.DEBUG,
        [logging.INFO]  = lsyslog.LEVEL.INFO,
        [logging.WARN]  = lsyslog.LEVEL.WARNING,
        [logging.ERROR] = lsyslog.LEVEL.ERR,
        [logging.FATAL] = lsyslog.LEVEL.ALERT,
    }

    if type(ident) ~= 'string' then
        ident = 'lua'
    end

    lsyslog.open(ident, facility or lsyslog.FACILITY.USER)

    return logging.new(function(self, level, message)
        lsyslog.log(convert[level] or lsyslog.LEVEL.ERR, message)
        return true
    end)
end

return logging.syslog
