require 'anemone'               # Ruby web spider
require 'capybara/poltergeist'  # Headless browsing and screenshot capture
require 'cgi'                   # URL escaping
require 'csv'                   # Write CSV file
require 'png_quantizator'       # Convert 32 to 8 PNGs - brew install pngquant

Capybara.default_driver = :poltergeist

module Hoarder
  extend Capybara::DSL
  
  def self.crawl(url, page_count=100)
    Anemone.crawl(url, {:delay => 1, :obey_robots_txt => true}) do |anemone|
      @titles = []
      anemone.on_every_page do |page|
        begin
          process_page(page)
        rescue Exception => e
          puts "Exception - #{e}: #{page.inspect}"
          next
        end
        exit_crawl?(page_count)
      end
    end
  end
  
  def self.process_page(page)
    title = page.doc.at('title') ? page.doc.at('title').inner_html : ""
    @titles.push title    
    write_data_to_csv(title,page)
    save_image(page.url)
  end
  
  # Write info to CSV
  def self.write_data_to_csv(title,page)
    CSV.open('pages.csv', 'a+') {|csv| csv << [title, page.url, page.code, page.response_time, page.depth]}
  end
  
  def self.save_image(url)
    visit(url)
    save_screenshot("#{CGI.escape(url.to_s)}.png", :full => true)
    PngQuantizator::Image.new("#{CGI.escape(url.to_s)}.png").quantize!
  end
  
  def self.exit_crawl?(page_count)
    exit if @titles.size == page_count
  end
end

Hoarder.crawl('http://library.wisc.edu', 10)
