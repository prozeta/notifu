class Notifu < Sinatra::Base

  class App

    ##
    # Initialization of Notifu::Model object
    #
    def initialize ( redis_host = "localhost", redis_port = 6379, conf = "" )
      @r = Redis.new(:host => "#{redis_host}", :port => "#{redis_port}")
      create_redis_structs conf
    end

    ##
    # Colorful debug helper
    #
    def debug (topic, message)
      if $debug
        print "DEBUG ".blue
        print "(#{topic}): ".green
        print "#{message}\n".yellow
        $stdout.flush
      end
    end

    ##
    # Creation of Redis structures
    # (runs on every request in case redis restarted and got empty in the meantime)
    #
    def create_redis_structs (conf)
      @r.exists "notifications" or @r.sadd "notifications", "placeholder"
      # @r.exists "teams" or @r.sadd "teams", "placeholder"
      # @r.exists "contacts" or @r.sadd "contacts", "placeholder"
      conf.each_key do |team|
        @r.exists "notifications:#{team}" or @r.sadd "notifications", "placeholder"
      end
    end

    def vacuum_notification_index
      index = db_get_all_notifications
      deleted = []
      puts "Index vacuum start"
      index.each do |key|
        if db_get_notification key
          puts "...skipping key: #{key}"
        else
          puts "...clearing key: #{key}"
          deleted.push key
        end
      end
      puts "Index vacuum result: " + deleted.to_s
      deleted
    end

    ##
    # Parse HTTP request to ruby hash
    #
    def parse_request (req)
      req.body.rewind
      debug __method__, req.body.read.to_s
      req.body.rewind
      JSON.parse(req.body.read.to_s) or 0
    end

    ##
    # Unique notification ID (Notifu ID)
    # (last 10 bytes from SHA256 digest of hostname, ip and service name
    #
    def generate_notification_id (hostname, ip, service)
      sha = Digest::SHA256.new
      sha.hexdigest("#{hostname}/#{ip}/#{service}").to_s[-10,10]
    end

    ##
    # Notifu notification object from sensu event data (as hash)
    #
    def create_notification_object (content)
      notification = {
        :id => "",
        :subject => {},
        :time => {},
        :sla => {},
        :status => {},
      }
      content["check"]["output"].chomp!
      content["check"]["output"].gsub! /\n/, ' '
      notification[:id] = generate_notification_id content["client"]["name"], content["client"]["address"], content["check"]["name"]
      notification[:subject][:host] = content["client"]["name"]
      notification[:subject][:address] = content["client"]["address"]
      notification[:subject][:service] = content["check"]["name"]
      notification[:subject][:occurences] = content["check"]["occurences"]
      notification[:time][:last_event] = content["check"]["issued"]
      notification[:time][:last_notification] = 0
      notification[:sla] = content["check"]["sla"]
      notification[:action] = content["action"]
      notification[:status][:code] = content["check"]["status"]
      notification[:status][:message] = content["check"]["output"]
      notification[:status][:occurences] = content["occurrences"]
      notification[:sla] ||= [ "devops:default" ]
      notification[:action] ||= "undefined"
      notification
    end

    ##
    # Get notification info from Redis by notifuID
    # (also adds notification to the "notification" Redis set if not already there)
    #
    def db_get_notification (id)
      member = true if @r.sismember "notifications", id != ""
      member ||= false

      if @r.exists "notification:#{id}"
        db_list_add_notification id if ! member
        ( subject, time, sla, status ) = @r.hmget "notification:#{id}", "subject", "time", "sla", "status"
        { :id => id,
          :subject => JSON.parse(subject, :symbolize_names => true),
          :time => JSON.parse(time, :symbolize_names => true),
          :sla => JSON.parse(sla, :symbolize_names => true),
          :status => JSON.parse(status, :symbolize_names => true) }
      else
        db_list_rem_notification id
        false
      end
    end

    ##
    # Get notification times from Redis
    #
    def db_get_notification_times (id)
      time = @r.hget "notification:#{id}", "time"
      JSON.parse time
    end

    ##
    # Get list of all notifuIDs from Redis
    #
    def db_get_all_notifications
      notifications = @r.smembers "notifications"
      notifications.delete "placeholder"
      notifications
    end

    ##
    # Write notification data to Redis
    #
    def db_set_notification (content, ttl)
      id = content[:id]
      [ "subject", "status", "sla", "time" ].each do |value|
        @r.hset "notification:#{id}", value, content[:"#{value}"].to_json
      end
      @r.expire "notification:#{id}", ttl
      db_list_add_notification id
      debug __method__, content.to_json
      debug __method__, "TTL: #{ttl}"

    end

    ##
    # Removes notification from Redis
    #
    def db_delete_notification (content)
      id = content
      [ "subject", "status", "sla", "time" ].each do |value|
        @r.hdel "notification:#{id}" , value
      end
      db_list_rem_notification id
      { "id" => id, "status" => "removed" }
    end

    ##
    # Adds notification to the main list in Redis
    #
    def db_list_add_notification (id)
      @r.sadd "notifications", id
    end

    ##
    # Removes notification from the main list in Redis
    #
    def db_list_rem_notification (id)
      @r.srem "notifications", id
    end

    ##
    # Adds notification to team list in Redis
    #
    def db_team_list_add_notification (id, team)
      @r.sadd "notifications:#{team}", id
    end

    ##
    # Removes notification from team list in Redis
    #
    def db_team_list_rem_notification (id, team)
      @r.srem "notifications:#{team}", id
    end

    ##
    # Removes all notifications from DB
    #
    def db_delete_all_notifications
      ids = db_get_all_notifications
      ids.each do |id|
        db_delete_notification id
      end
    end

    ##
    # Update notification
    #
    def db_update_notification (notification, result, ttl)
      current = db_get_notification notification[:id]
      current[:subject][:occurences] = notification[:subject][:occurences]
      current[:sla] = notification[:sla]
      current[:time][:last_event] = notification[:time][:last_event]
      if result["destinations"]["report"].length > 0 or result["destinations"]["duty"].length > 0
        current[:time][:last_notification] = Time.now.to_i
        current[:status][:code] = notification[:status][:code]
        current[:status][:message] = notification[:status][:message]
      end
      current[:status][:occurences] = notification[:status][:occurences]
      db_set_notification current, ttl
    end


    ##
    # Get stashes (silenced hosts and checks) from Sensu API
    #
    def sensu_get_stashes (host, port)
      begin
        r = RestClient::Resource.new("http://#{host}:#{port}/stashes", :timeout => 30)
        JSON.parse r.get
      rescue
        []
      end
    end

    ##
    # Get stashes (silenced hosts and checks) from Sensu API
    #
    def is_silenced (host, port, notification)
      stashed = sensu_get_stashes host, port
      if notification[:subject][:service] == "keepalive"
        subject = "silence/#{notification[:subject][:host]}"
      else
        subject = "silence/#{notification[:subject][:host]}/#{notification[:subject][:service]}"
      end
      stashed.include?(subject)
    end


    ##
    # Process messages and send them to their destinations
    # (duty time & renotification interval logic is here)
    #
    # Status:
    #   _code: exit code of the check
    #   _nonsla: 0bXX (binary format)
    #     - silenced?
    #     - not enough occurrences?
    #   group: 0bXXX (binary format)
    #     - not duty time?
    #     - haven't reached renotification interval yet?
    #     - isn't recovery from critical?
    #
    def process_messages (global_conf, conf, notification, last_notification, last_code)
      now = Time.now
      destinations = {}
      status = {}
      status["_nonsla"] = 0b00
      duty_dow = now.wday - 1 # getting current day of week
      duty_dow = 6 if duty_dow < 0 # Sunday fix (we're not American ;])
      silenced = is_silenced global_conf["sensu_api_host"], global_conf["sensu_api_port"], notification
      occurences = notification[:subject][:occurences].to_i
      occured = notification[:status][:occurences].to_i
      code = notification[:status][:code]
      status["_code"] = notification[:status][:code]
      status["_action"] = notification[:action]
      destinations["duty"] = []
      destinations["report"] = []

      if occured >= occurences
        if ! silenced
          notification[:sla].each do |sla|
            ( group, duty_level ) = sla.split /:/
            duty_from = duty_until = 0
            duty_period = conf[group]["sla"][duty_level]["timeranges"][duty_dow]
            m = duty_period.match /^([0-9]{1,2})\:([0-9]{2})\-([0-9]{1,2})\:([0-9]{2})$/
            duty_from = Time.local( now.year, now.month, now.day, m[1], m[2] ).to_i
            duty_until = Time.local( now.year, now.month, now.day, m[3], m[4] ).to_i
            renotification_interval = conf[group]["sla"][duty_level]["renotification_interval"].to_i
            status[group] = 0b000
            fallback_contacts = conf[group]["fallback_members"]

            case code # notification type (based on exit code)
            when 0 # OK (sending duty messages for recoveries from critical during duty time and reports for all recoveries at all times)
              if duty_from < now.to_i and now.to_i < duty_until # is it on-duty time ?
                if last_code > 1 # is it recovery from critical?
                  destinations["duty"] << send_duty_messages(group, conf, notification, fallback_contacts, last_notification, last_code)
                else # isn't recovery from critical
                  status[group] += 0b001
                end
              else
                status[group] += 0b100
              end
              destinations["report"] << send_report_messages(group, conf, notification, fallback_contacts, last_notification, last_code)
            when 1 # WARNING (sending reports for warnings every renotification interval)
              if ( last_notification + renotification_interval ) <= now.to_i # is it time to renotify ?
                destinations["report"] << send_report_messages(group, conf, notification, fallback_contacts, last_notification, last_code)
              else
                status[group] += 0b010
              end
            when 2 # CRITICAL (sending duty messages for critical during duty time and reports for all critical at all times)
              if ( last_notification + renotification_interval ) <= now.to_i # is it time to renotify ?
                if duty_from < now.to_i and now.to_i < duty_until
                  destinations["duty"] << send_duty_messages(group, conf, notification, fallback_contacts, last_notification, last_code)
                else
                  status[group] += 0b100
                end
                destinations["report"] << send_report_messages(group, conf, notification, fallback_contacts, last_notification, last_code)
              else
                status[group] += 0b010
              end
            else
              destinations["report"] << send_report_messages(group, conf, notification, fallback_contacts, last_notification, last_code)
            end
          end
        else # is silenced
          status["_nonsla"] += 0b10
        end
      else # not enough occurences
        status["_nonsla"] += 0b01
      end

      destinations["duty"].flatten!
      destinations["report"].flatten!
      { "notification" => notification[:id], "status" => status, "destinations" => destinations }
    end

    ##
    # Send duty messages function
    # (send duty SMSs)
    #
    def send_duty_messages (group, conf, notification, default_contacts, last_notification, last_code)
      now = Time.now
      status_names = [ "OK", "WARN", "CRIT", "UNKN" ]
      message = notification[:subject][:host] + "/" + notification[:subject][:service] + " " +  status_names[notification[:status][:code]] + " (" + notification[:status][:message] + ")" + " id:" + notification[:id] + " " + now.to_s
      out = []
      users = db_get_duty_contacts group, default_contacts
      contacts = conf[group]["members"]
      users.each do |user|
        cell = contacts[user]["cell"]
        send_sms cell, message
        out.push user
      end
      out
    end

    ##
    # Send report messages function
    # (sends mail reports)
    #
    def send_report_messages (group, conf, notification, default_contacts, last_notification, last_code)
      now = Time.now
      status_names = [ "OK", "WARNING", "CRITICAL", "UNKNOWN" ]
      subject = "[#{group}] - #{notification[:subject][:host]}/#{notification[:subject][:service]} #{status_names[notification[:status][:code]]}"
      if last_notification == 0
        last_notification = "NEVER"
      else
        last_notification = Time.at(last_notification).to_s
      end
      message = $report_template.result(binding)
      out = []
      to = []
      contacts = conf[group]["members"]
      users = db_get_report_contacts group, default_contacts
      users.each do |user|
        to.push contacts[user]["name"] + " <" + contacts[user]["mail"] + ">"
        out.push user
      end
      send_mail to.join(", "), subject, message
      out
    end


    ##
    # Send notification via SMS
    #
    def send_sms (number, text)
      template = ERB.new $sms_command
      debug __method__, template.result(binding)
      smsjob = fork do
        system template.result(binding)
      end
      Process.detach(smsjob)
    end

    ##
    # Send notification via mail
    # TBD
    #
    def send_mail (address, subject, message)
      mail = Mail.new do
        from $mail_from
        to address
        subject subject
        text_part do
          body 'This is HTML e-mail'
        end
        html_part do
          content_type 'text/html; charset=UTF-8'
          body message
        end
      end
      mail.delivery_method :smtp, {
        :address => "smtp.gmail.com",
        :port => 587,
        :user_name => $mail_from,
        :password => $mail_pass,
        :authentication => :plain,
        :enable_starttls_auto => true
      }
      debug __method__, mail.to_s
      mailjob = fork do
        mail.deliver
      end
      Process.detach(mailjob)
    end

    ##
    # Get contacts from database
    # (sets fallback contact if unset)
    #
    def db_get_contacts (group, default_contacts)
      @r.exists "group:#{group}" or ( @r.hset "group:#{group}", "contacts", default_contacts.to_json; @r.hset "group:#{group}", "update_method", "fallback" )
      contacts = @r.hget "group:#{group}", "contacts"
      method = @r.hget "group:#{group}", "update_method"
      { "contacts" => JSON.parse(contacts), "update_method" => method }
    end

    ##
    # Get contacts from database
    # (sets fallback contact if unset)
    #
    def db_get_duty_contacts (group, default_contacts)
      contacts = db_get_contacts group, default_contacts
      contacts["contacts"]["duty"]
    end

    ##
    # Get contacts from database
    # (sets fallback contact if unset)
    #
    def db_get_report_contacts (group, default_contacts)
      contacts = db_get_contacts group, default_contacts
      contacts["contacts"]["report"]
    end

    ##
    # Set duty contacts
    #
    def db_set_duty_contacts (group, contacts, method, default_contacts)
      current = db_get_contacts group, default_contacts
      current["contacts"]["duty"] = contacts
      @r.hset "group:#{group}", "contacts", current["contacts"].to_json
      @r.hset "group:#{group}", "update_method", method
    end

    ##
    # Set report contacts
    #
    def db_set_report_contacts (group, contacts, method, default_contacts)
      current = db_get_contacts group, default_contacts
      current["contacts"]["report"] = contacts
      @r.hset "group:#{group}", "contacts", current["contacts"].to_json
      @r.hset "group:#{group}", "update_method", method
    end

  end

###
### MAIN APP CODE
###

  ##
  # Initial config
  #
  conf_dir = "./config"
  global_conf = YAML.load_file("#{conf_dir}/notifu.yaml") or exit 1
  conf = {}
  Dir["#{conf_dir}/groups/*.yaml"].each do |file|
    group_name = file.sub(/^.+\/([a-zA-Z0-9\-\_]+)\.yaml$/, '\1')
    conf[group_name] = YAML.load_file(file)
  end
  $sms_command = global_conf["sms_command"]
  $mail_from = global_conf["mail_from"]
  $mail_pass = global_conf["mail_pass"]
  $report_template = ERB.new File.new("#{conf_dir}/mail.erb").read
  $debug = global_conf["debug"]

  ##
  # App creation
  #
  a = App.new( global_conf["redis_host"], global_conf["redis_port"], conf )

  ##
  # Landing page
  # (might be used for some kind of dashboard in the future)
  #
  get "/" do
    "<html><body><h1>Sensu Notification WebService</h1></body></html>"
  end

  ##
  # Processing notification
  #
  # POST /api/notification
  # => {
  #   "client":{
  #     "name":"es1-2.candycloud.eu",
  #     "address":"10.126.132.83",
  #     "subscriptions":[
  #       "default",
  #       "elasticsearch"
  #     ],
  #     "timestamp":1362581248
  #   },
  #   "check":{
  #     "command":"PATH=/usr/bin:/bin:/usr/sbin:/sbin:/etc/sensu/plugins: check-load.rb -c 50,30,15 -w 25,15,10",
  #     "standalone":true,
  #     "interval":60,
  #     "occurences":2,
  #     "sla":[
  #       "devops:default"
  #     ],
  #     "subscribers":[
  #       "default"
  #     ],
  #     "handlers":[
  #       "default"
  #     ],
  #     "name":"check-load",
  #     "issued":1362581266,
  #     "output":"CheckLoad CRITICAL: Load average: 370.46, 386.29, 333.94\n",
  #     "status":2,
  #     "duration":0.496,
  #     "history":[
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2",
  #       "2"
  #     ]
  #   },
  #   "occurrences":391,
  #   "action":"create"
  # }
  #
  post "/api/notification" do
    debug_context = "POST /api/notification"
    ttl = 3600*12 # Redis TTL in seconds
    now = Time.now
    notification = a.create_notification_object a.parse_request request # processing request on input
    db_notification = a.db_get_notification(notification[:id])
    if not db_notification
      a.db_set_notification notification, ttl
      db_notification = a.db_get_notification(notification[:id])
      a.debug debug_context, "first notification, added to db"
    end
    a.debug debug_context, "ingress:\n" + db_notification.to_json
    last_notification = db_notification[:time][:last_notification]
    last_code = db_notification[:status][:code]
    result = a.process_messages global_conf, conf, notification, last_notification, last_code
    if result["status"]["_action"] == "resolve"
      ttl = 10
    end
    a.db_update_notification notification, result, ttl
    a.debug debug_context, "egress:\n" + a.db_get_notification(notification[:id]).to_json
    result["subject"] = "#{notification[:subject][:host]}/#{notification[:subject][:service]}"
    puts Time.now.to_s + ": " + result.to_json
    result.to_json
  end

  ##
  # Listing all notifications
  #
  # GET /api/notification/all
  #
  get "/api/notification/all" do
    a.db_get_all_notifications.to_json
  end

  ###
  # Vacuum notification index
  # 
  get "/api/notification/vacuum" do
    a.vacuum_notification_index.to_json
  end

  ##
  # Showing one notification by ID
  #
  # GET /api/notification/be6d8db6f6
  #
  get "/api/notification/:id" do
    a.db_get_notification(params[:id]).to_json
  end

  # Deleting all saved notifications
  #
  # DELETE /api/notification/all
  #
  delete "/api/notification/all" do
    a.db_delete_all_notifications.to_json
  end

  ##
  # Deleting a notification by ID
  #
  # DELETE /api/notification/be6d8db6f6
  #
  delete "/api/notification/:id" do
    a.db_delete_notification(params[:id]).to_json
  end

  ##
  # Showing duty for a group
  #
  # GET /api/duty/devops
  #
  get "/api/duty/:id" do
    halt 404, { "status" => "no such group - #{params[:id]}" }.to_json if ! conf[params[:id]]
    a.db_get_duty_contacts(params[:id], conf[params[:id]]["fallback_members"]).to_json
  end

  ##
  # Setting duty for a group
  #
  # POST /api/duty/devops
  # => {"contacts": ["blufor","skom"]}
  #
  post "/api/duty/:id" do
    halt 404, { "status" => "no such group - #{params[:id]}" }.to_json if ! conf[params[:id]]
    data = a.parse_request request
    a.db_set_duty_contacts params[:id], data["contacts"], "api", conf[params[:id]]["fallback_members"]
    a.db_get_duty_contacts(params[:id], conf[params[:id]]["fallback_members"]).to_json
  end

  ##
  # Showing reported users for a group
  #
  # GET /api/report/devops
  #
  get "/api/report/:id" do
    halt 404, { "status" => "no such group - #{params[:id]}" }.to_json if ! conf[params[:id]]
    a.db_get_report_contacts(params[:id], conf[params[:id]]["fallback_members"]).to_json
  end

  ##
  # Setting reported users for a group
  #
  # POST /api/report/devops
  # => {"contacts": ["blufor","skom"]}
  #
  post "/api/report/:id" do
    halt 404, { "status" => "no such group - #{params[:id]}" }.to_json if ! conf[params[:id]]
    data = a.parse_request request
    a.db_set_report_contacts params[:id], data["contacts"], "api", conf[params[:id]]["fallback_members"]
    a.db_get_report_contacts(params[:id], conf[params[:id]]["fallback_members"]).to_json
  end
  
  ##
  # Errorpage
  #
  error do
    "Error"
  end

end
