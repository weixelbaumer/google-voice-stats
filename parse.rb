#!/usr/bin/env ruby
require 'pandoc-ruby'
require 'time'
require 'ohm'
require './models/person.rb'
require 'digest/md5'

Ohm.connect(:db => "15")

def parse(person = nil)
  $all_c = []
  puts "Start #{Time.now}"
  s = Dir.new(File.join('.', 'data'))
  files = []
  unless person.nil?
    s.each {|file|  if file.include? person and !file.include? ".mp3" and !File.directory?(File.join('.', 'data', file)) then files << file end }
  else
    s.each {|file|  if !file.include? ".mp3" and !File.directory?(File.join('.', 'data', file)) then files << file end }
  end
  s.close
  puts "Total: #{files.count}"
  files.each_with_index do |file, i|
    putc "."
    if (i + 1) % 20 == 0 then puts i+1 end
    o_file = File.open(File.join('.', 'data', file)).readlines.join
    begin
      title = o_file.match(/\<title\>(.*?)<\/title\>/xm)[1].dump.gsub(/\\n/," ").gsub("Me to ", "").slice(1..-2).gsub("&quot;", "").gsub("'", "").gsub('"', "")
    rescue NoMethodError
      title = "No name"
    end
    # puts "#{file} #{if title then title end }"
    doc = PandocRuby.new(o_file, :from => :html, :to => :markdown).convert

    lines = []
    doc.split(/\n/).each {|line| lines << line }

    fixed = []
    if lines then lines.reject! {|x| x.match(/^(Labels.*|\[Text.*)/)} end

    begin
      lines.each do |line|
        unless line.match(/^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/)
          fixed << fixed.pop.chomp + " " + line
        else
          fixed << line
        end
      end
    rescue NoMethodError
    end

    fixed.each do |message|
      h = {}
      date = message.match(/^[a-zA-Z]{3} .* Time/)
      who = message.match(/(\[.*?\]|\[Me\])/)
      content = message.match(/(?:\): ).*$/)

      if date && who && content then
        h["date"] = DateTime.parse(date[0])
        h["from"] = who[0].slice(1..-2).gsub("&quot;", "").gsub("'", "").gsub('"', "")
        unless Person.with(:name, h["from"]) then Person.create(:name => h["from"]) end
        h["content"] = content[0].slice(3..-1)
        if h["from"] != "Me" then h["to"] = "Me" else h["to"] = title end
        unless Person.with(:name, h["to"]) then Person.create(:name => h["to"]) end
        prehash = "#{h["date"]}#{h["from"]}#{h["content"]}"
        posthash = Digest::MD5.digest(prehash)
        unless Message.with(:hash, posthash)
          Message.create(:date => h["date"], :content => h["content"], :sent_by => Person.with(:name, h["from"]), :sent_to => Person.with(:name, h["to"]), :hash => posthash)
        end
      end
    end
  end
  puts "End:  #{Time.now}"
end

parse(ARGV.first)
