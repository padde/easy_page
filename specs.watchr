require 'ansi'
require 'redcarpet'
require 'erb'
require 'pathname'
require 'nokogiri'
require 'albino'
require 'sass'

SETTINGS = {
  :output_folder => 'out',
  :source_folder => 'src',
  :template_folder => 'templates',
  :template => 'main'
}

MARKDOWN_OPTIONS = [:hard_wrap, :autolink, :no_intraemphasis, :fenced_code, :gh_blockcode]


def path opts={}
  folder = opts[:folder].gsub /\./, '\.'
  extension = opts[:extension].gsub /\./, '\.'
  /#{folder}[\/.]+.*\.#{extension}/
end

def notify ( message, type = :message, typetext = nil )
  color = ANSI::Code.green
  color = ANSI::Code.red    if type == :error
  color = ANSI::Code.yellow if type == :note
  
  typetext = :note.to_s if typetext.nil?
  
  puts "#{color+typetext.ljust(10)+ANSI::Code.reset} #{message}"
end

def template_filename
  SETTINGS[:template_folder] + '/' + SETTINGS[:template] + '.html.erb'
end

def apply_template
  template = File.read(template_filename)
  ERB.new(template).result(binding)
end

# from http://railscasts.com/episodes/272-markdown-with-redcarpet
def syntax_highlighter html
  doc = Nokogiri::HTML(html)
  doc.search("//pre[@lang]").each do |pre|
    pre.replace Albino.colorize(pre.text.rstrip, pre[:lang])
  end
  doc.to_s
end

def process_markdown file
  source = File.read(file)
  html = apply_template{ Redcarpet.new(source, *MARKDOWN_OPTIONS).to_html }
  html = syntax_highlighter(html)
  
  filename = File.basename(file, File.extname(file))
  outsubfolder = File.dirname(file).gsub(/#{SETTINGS[:source_folder]}\/?/,'') + '/'
  outfile = SETTINGS[:output_folder] + '/' + outsubfolder + filename + '.html'
  FileUtils.mkdir_p File.dirname(outfile)
  
  File.open(outfile, 'w') do |f|
    f.write(html)
  end
  
  notify file, :message, 'compile'
end

def process_sass file
  source = File.read(file)
  
  engine = Sass::Engine.new(source, :syntax => :scss)
  css = engine.render
  
  filename = File.basename(file, File.extname(file))
  outsubfolder = File.dirname(file).gsub(/#{SETTINGS[:source_folder]}\/?/,'') + '/'
  outfile = SETTINGS[:output_folder] + '/' + outsubfolder + filename + '.css'
  FileUtils.mkdir_p File.dirname(outfile)
  
  File.open(outfile, 'w') do |f|
    f.write(css)
  end
  
  notify file, :message, 'compile'
end




puts "Now watching your source folder (#{SETTINGS[:source_folder]}/)"
puts "Press CTRL-C to quit"

watch path(:folder => SETTINGS[:source_folder], :extension => 'markdown') do |md|
  process_markdown md[0]
end

watch path(:folder => SETTINGS[:template_folder], :extension => 'html.erb') do |md|
  notify md[0], :note, 'changed'
  Dir[SETTINGS[:source_folder]+'/**/*.*'].each do |file|
    process_markdown file
  end
end

watch path(:folder => SETTINGS[:source_folder], :extension => 'scss') do |md|
  process_sass md[0]
end

watch path(:folder => SETTINGS[:source_folder], :extension => 'css') do |md|
  src = md[0]
  dst = SETTINGS[:output_folder] + '/' + src.gsub(/#{SETTINGS[:source_folder]}\/?/,'')
  FileUtils.copy(src, dst)
  notify md[0], :message, 'copy'
end

