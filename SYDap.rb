#!/usr/bin/env ruby

require 'rubygems'
require 'mechanize'
require 'action_view'
include ActionView::Helpers::DateHelper
require 'twitter'

PATH_PREFIX = File.expand_path(File.dirname(__FILE__))
config = YAML.parse(File.read(PATH_PREFIX + "/creds.yml"))

%w{consumer_key consumer_secret access_token access_token_secret}.each do |key|
  Object.const_set(key.upcase, config["config"][key].value)
end

Twitter.configure do |config|
  config.consumer_key = CONSUMER_KEY
  config.consumer_secret = CONSUMER_SECRET
  config.oauth_token = ACCESS_TOKEN
  config.oauth_token_secret = ACCESS_TOKEN_SECRET
end

def get_latest_flights(url, seconds_old, arrival)
  agent = Mechanize.new
  page = agent.get(url)

  # Columns: Airline (image), Flight #, Destination, Scheduled, Estimated, Check-in desk, Status
  rows = page.at('table/tbody').search('tr')

  latest_rows = rows.select do |r|
    estimated_time = r.search('td')[4].inner_html.split('<br>')[1]
    estimated_time = Time.parse(estimated_time) if estimated_time
    estimated_time and estimated_time < Time.now and estimated_time > (Time.now - seconds_old)
  end

  type = arrival ? "arrival" : "departure"

  latest_rows.map do |r|
    {
      :number => r.search('td')[1].inner_text.strip,
      :airline => r.search('td')[0].at('img').attribute('alt').inner_text.strip,
      :destination => r.search('td')[2].inner_html.strip.gsub('<br>', ' & '),
      :scheduled_time => Time.parse(r.search('td')[3].inner_html.split('<br>')[1]),
      :estimated_time => Time.parse(r.search('td')[4].inner_html.split('<br>')[1]),
      :type => type
    }
  end
end

# Get flights for last x seconds
seconds_old = 60

international_departures = get_latest_flights('http://www.sydneyairport.com.au/SACL/International-Departures.html?results=1000', seconds_old, false)
international_arrivals = get_latest_flights('http://www.sydneyairport.com.au/SACL/International-Arrivals.html?results=1000', seconds_old, true)

latest_flights = (international_departures + international_arrivals).sort do |a, b|
  a[:estimated_time] <=> b[:estimated_time]
end

latest_flights.each do |flight|
  # Qantas flight #QF123 to Auckland & Wellington just took off, 10 minutes late
  tweet = "#{flight[:airline]} flight ##{flight[:number]}"
  tweet += flight[:type] == "departure" ? " to" : " from"
  tweet += " #{flight[:destination]} just"
  tweet += flight[:type] == "departure" ? " took off" : " landed"
  if flight[:scheduled_time] != flight[:estimated_time]
    tweet += ", #{distance_of_time_in_words(flight[:scheduled_time], flight[:estimated_time])}"
    tweet += flight[:estimated_time] > flight[:scheduled_time] ? " late" : " early"
  end
  
  # I don't think it should ever be larger than 140 characters
  Twitter.update(tweet)
end
