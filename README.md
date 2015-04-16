Notifu
======
Sensu notification REST API handler. This documentation is work-in-progress

Features
--------
  - Sensu notification multiplexing
  - Sensu handler supplied for events.
  - configurable notification groups with any number of SLA sub-groups including renotification interval per each and timeperiods per day of week
  - Can be run in HA mode (only PITA is Redis, which can be handled by redis-sentinel).
  - Processing logging to ElasticSearch

Screenshots
-----------
*"cuz seeing is believing"*

**E-mail report:**

![e-mail report](report.png "e-mail report")

**Duty SMS notification:**

![duty SMS notification](duty_notification.png "duty SMS notification")

Prerequisities
---------------
  - running Sensu architecture
  - Redis (>= 2.x) (you can use the same as for sensu)
  - Created user with RVM installed
  - properly set-up handler on your Sensu checks

Installation
------------
*TODO*

Configuration
-------------
*TODO*