require 'anemone'               # Ruby web spider
require 'mongo'                 # MongoDB
require 'capybara/webkit'       # Open URL
require 'capybara-screenshot'   # Save image
require 'cgi'                   # URL escaping
require 'csv'                   # Write CSV file
require 'png_quantizator'       # Convert 32 to 8 PNGs - brew install pngquant

# @TODO: mongodb + delayed_job integration
# - Image capture causes a large crawls page_queue to slow until it ultimately hangs
# - Need to push image capture to background process

Capybara.default_driver = :webkit

module Hoarder
  extend Capybara::DSL
  
  # Walk the domain
  def self.crawl(url, page_count=100)
    Anemone.crawl(url, {:delay => 2, :obey_robots_txt => true, :skip_query_strings => true}) do |anemone|
      # Do not crawl doc extensions
      # @TODO: Don't get trapped on calendars
      ext = %w(flv swf png jpg gif asx zip rar tar 7z gz jar js css dtd xsd ico raw mp3 mp4 wav wmv ape aac ac3 wma aiff mpg mpeg avi mov ogg mkv mka asx asf mp2 m1v m3u f4v pdf doc xls ppt pps bin exe rss xml)
      anemone.skip_links_like(/\.#{ext.join('|')}$/)
      anemone.storage = Anemone::Storage.MongoDB
      anemone.on_every_page do |page|
        begin
          process_page(page)
        rescue Exception => e
          puts "Exception - #{e}"
          next
        end
        exit_crawl?(page_count)
      end
    end
  end
  
  # Data and image capture
  def self.process_page(page)
    # Skip redirects and pages with iframes
    unless page.code == 302 or page.doc.at('iframe')
      page.data = {}
      page.data[:title] = begin page.doc.at('title').inner_html rescue "" end
      visit(page.url.to_s)
      save_image(CGI.escape(page.url.to_s))
    end
  end

  # Save optimized screenshot PNG
  def self.save_image(url)
    saver = Capybara::Screenshot::Saver.new(Capybara, Capybara.page, false, url)
    saver.save
    PngQuantizator::Image.new(saver.screenshot_path).quantize!
  end
  
  # Shall we keep crawling?
  def self.exit_crawl?(page_count)
    exit if @pages.count == page_count
  end
end

Hoarder.crawl('http://library.wisc.edu', 100)
