##
# Require block
#
require "ohm"
require "elasticsearch"
require "log4r/outputter/syslogoutputter"
require "log4r/configurator"
require "log4r"
require "syslog"
require "sidekiq"
require "sidekiq/logging"
require_relative "../mixins.rb"
require_relative "../util.rb"
require_relative "../config.rb"
require_relative "../logger.rb"
require_relative "../model/contact.rb"
require_relative "../model/sla.rb"
require_relative "../model/group.rb"
require_relative "../model/event.rb"
require_relative "../model/issue.rb"

##
# Config block
#
Notifu::CONFIG = Notifu::Config.new.get

##
# Ohm init
#
Ohm.redis = Redic.new Notifu::CONFIG[:redis_data]