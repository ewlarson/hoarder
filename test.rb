require 'anemone'
require 'capybara/webkit'
require 'capybara-screenshot'
require 'cgi'

# brew install optipng
require 'piet'

# brew install pngquant
require 'png_quantizator'

Capybara.default_driver = :webkit

module TinyWeb
  extend Capybara::DSL
  extend Capybara::Screenshot
  
  def self.crawl(url, page_count=100)
    Anemone.crawl(url, {:delay => 3, :obey_robots_txt => true}) do |anemone|
      @titles = []
      anemone.on_every_page do |page|
        begin
          title = page.doc.at('title').inner_html rescue nil
  
          if title && title != "302 Found"
            File.open('pages.txt', 'a+') {|file| file.puts("#{title} - #{page.url}")}
            @titles.push title
            visit(page.url)
            save_image(CGI.escape(page.url.to_s))
          else
            puts("#{title} - #{page.url}")
          end
        rescue Exception => e
          puts "Exception - #{title}: #{e.inspect}"
          next
        end

        if @titles.size == page_count
          exit
        end
      end
    end
  end
  
  def self.save_image(url)
    saver = Capybara::Screenshot::Saver.new(Capybara, Capybara.page, false, url)
    saver.save
    Piet.pngquant(saver.screenshot_path)
  end
end

TinyWeb.crawl('http://library.wisc.edu')
