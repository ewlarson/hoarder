require 'anemone'               # Ruby web spider
require 'mongo'                 # MongoDB
require 'capybara/webkit'       # Open URL
require 'capybara-screenshot'   # Save image
require 'cgi'                   # URL escaping
require 'png_quantizator'       # Convert 32 to 8 PNGs - brew install pngquant

Capybara.default_driver = :webkit

module Hoarder
  extend Capybara::DSL
  
  # MongoDB
  @db = Mongo::Connection.new.db("hoarder")
  @pages = @db["pages"]
  
  # Walk the domain
  def self.crawl(url, page_count=100)
    Anemone.crawl(url, {:delay => 2, :obey_robots_txt => true}) do |anemone|
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
      title = page.doc.at('title') ? page.doc.at('title').inner_html : ""
      
      if title
        page = {title: title, url: page.url.to_s, code: page.code, response_time: page.response_time}
        puts "Inserting #{page.inspect}"
        @pages.insert page
      end
      
      #write_data_to_csv(title,page)
      visit(page[:url])
      save_image(CGI.escape(page[:url]))
    end
  end
  
  # Write page data to CSV
  #def self.write_data_to_csv(title,page)
  #  CSV.open('pages.csv', 'a+') {|csv| csv << [title, page.url, page.code, page.response_time, page.depth]}
  #end

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

Hoarder.crawl('http://library.wisc.edu', 10)
