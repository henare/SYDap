#!/usr/bin/env ruby

require 'rubygems'
require 'mechanize'
require 'action_view'
include ActionView::Helpers::DateHelper

@agent = Mechanize.new

def get_latest_flights(url, seconds_old, arrival)
  page = @agent.get(url)

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
  puts tweet
end
