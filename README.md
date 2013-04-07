Notifu
======
Sensu notification REST API handler. This documentation is work-in-progress

Prerequisities
---------------
  - running Sensu architecture
  - Redis (>= 2.x) (you can use the same as for sensu)
  - Ruby (>= 1.8.7)
  - Ruby Bundler
  - custom variable for each check with `"sla": ["<group_name>:<sla_level>", ...]` (groups and SLA levels are covered in Installation)

Installation
------------
  - clone this repo
  - create config/notifu.yaml from example
  - create at least one group (config/groups/_group_name>_.yaml)
  - run `bundle install`
  - run `bundle exec ruby run.rb &`
  - put following configuration in Sensu's config.json:

```
"handlers": {
  "notifu": {
    "type": "pipe",
    "command": "/usr/bin/curl -X POST -d @- -H 'Content-type: application/json' http://notifu-host:8000/api/notification",
    "severities": [
      "ok",
      "warning",
      "critical"
    ]
  }
}
```
