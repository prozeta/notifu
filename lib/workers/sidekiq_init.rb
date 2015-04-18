##
# Require block
#
basepath = File.dirname(__FILE__).sub(/\/workers$/, "/")
requires = Array.new
requires << "ohm"
requires << "elasticsearch"
requires << "log4r/outputter/syslogoutputter"
requires << "log4r/configurator"
requires << "log4r"
requires << "syslog"
requires << "sidekiq"
requires << "sidekiq/logging"
requires << basepath + "mixins.rb"
requires << basepath + "util.rb"
requires << basepath + "config.rb"
requires << basepath + "logger.rb"
requires << basepath + "model/contact.rb"
requires << basepath + "model/sla.rb"
requires << basepath + "model/group.rb"
requires << basepath + "model/event.rb"
requires << basepath + "model/issue.rb"
requires.each { |lib| require lib }

##
# Config block
#
Notifu::CONFIG = Notifu::Config.new.get

##
# Ohm init
#
Ohm.redis = Redic.new Notifu::CONFIG[:redis_data]