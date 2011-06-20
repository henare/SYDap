SYDap
=====

SYDap.rb is a bot that tweets the international arrivals and departures from Sydney Airport.

Inspired by and some code from https://github.com/infovore/tower-bridge

Configuration
-------------

* Fill out your own creds.yml with the Twitter OAuth credentials you've acquired when you created an application on (developer.twitter.com)
* Put all these files on a server
* `bundle install`
* `whenever --update-crontab`
* That's it. The bot will tweet once a minute
