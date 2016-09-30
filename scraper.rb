#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'cgi'
require 'mechanize'


class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(noko)
  url = 'http://www.congreso.gob.pe/plenaryassembly' # for now
  noko.xpath('//table[@class="congresistas"]//tr[td]').each do |tr|
    tds = tr.css('td')
    source = URI.join(url, tds[1].css('a/@href').text).to_s
    data = { 
      id: CGI.parse(URI.parse(source).query)['id'].first,
      sort_name: tds[1].text.tidy,
      # faction: tds[2].text.tidy,
      email: tds[3].css('a[href*="mailto:"]/@href').text.sub('mailto:',''),
      image: tds[0].css('img/@src').text,
      term: '2011',
      source: source.to_s,
    }.merge(scrape_person(source))
    data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
    puts data
    ScraperWiki.save_sqlite([:id, :term], data)
  end
end

def scrape_person(url)
  noko = noko_for(url)
  data = { 
    name: noko.css('.nombres .value').text,
    party: noko.css('.grupo .value').text,
    faction: noko.css('.bancada .value').text,
    area: noko.css('.representa .value').text,
    status: noko.css('.condicion .value').text,
  }
  data[:start_date], data[:end_date] = noko.css('.periododatos .value').map { |t| Date.parse(t.text).to_s }
  data
end

start_url = 'http://www.congreso.gob.pe/plenaryassembly?K=364'
data_url = 'http://www.congreso.gob.pe/members?m1_idP=6'
agent = Mechanize.new

page = agent.get(start_url)
headers = {
  'Referer' => start_url,
  'Cookie' => page.header["set-cookie"]
}

agent.request_headers = headers
page = agent.get(data_url)
scrape_list(page.parser)
