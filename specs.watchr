require 'ansi'
require 'redcarpet'
require 'erb'
require 'nokogiri'
require 'albino'
require 'sass'


SETTINGS = {
  :output_dir   => 'out',
  :source_dir   => 'src',
  :template_dir => 'templates',
  :template     => 'main'
}

MARKDOWN_OPTIONS = [
  :hard_wrap, 
  :autolink, 
  :no_intraemphasis, 
  :fenced_code, 
  :gh_blockcode
]


def path_regex opts={}
  opts[:folder] ||= SETTINGS[:source_dir]
  folder = opts[:folder].gsub /\./, '\.'
  extension = opts[:extension].gsub /\./, '\.'
  /#{folder}[\/.]+.*\.#{extension}/
end

def destination_of infile, opts={}
  opts[:old_ext] ||= File.extname(infile)
  opts[:new_ext] ||= opts[:old_ext]
  opts[:old_ext] = '.' + opts[:old_ext] unless opts[:old_ext].match /^\..*/
  opts[:new_ext] = '.' + opts[:new_ext] unless opts[:new_ext].match /^\..*/
  
  infile = File.absolute_path( infile )
  source_dir = File.absolute_path( SETTINGS[:source_dir] )
  output_dir = File.absolute_path( SETTINGS[:output_dir] )
  
  source_regex = Regexp.new( source_dir )
  ext_regex = Regexp.new( opts[:old_ext].gsub(/\./,'\.') )
  
  infile.gsub( source_regex, output_dir ).gsub( ext_regex, opts[:new_ext] )
end

def notify ( message, type = :message, typetext = nil )
  color = ANSI::Code.green
  color = ANSI::Code.red    if type == :error
  color = ANSI::Code.yellow if type == :note
  
  typetext = :note.to_s if typetext.nil?
  puts "#{color + typetext.ljust(10) + ANSI::Code.reset} #{message}"
end

def apply_template
  template_file = SETTINGS[:template_dir] + '/' + SETTINGS[:template] + '.html.erb'
  template = File.read(template_file)
  ERB.new(template).result(binding)
end

def syntax_highlighter html
  doc = Nokogiri::HTML(html)
  doc.search("//pre[@lang]").each do |pre|
    pre.replace Albino.colorize(pre.text.rstrip, pre[:lang])
  end
  doc.to_s
end

def process_file infile, opts={}
  opts[:message] ||= 'compile'
  opts[:new_ext] ||= ''
  
  source = File.read(infile)
  content = yield source
  
  outfile = destination_of infile, :new_ext => opts[:new_ext]
  FileUtils.mkdir_p File.dirname(outfile)
  
  File.open(outfile, 'w') do |f|
    f.write(content)
  end
  
  notify infile, :message, opts[:message]
end

def process_markdown infile
  process_file infile, :new_ext => 'html' do |source| 
    html = Redcarpet.new(source, *MARKDOWN_OPTIONS).to_html
    html = apply_template{ html }
    syntax_highlighter(html)
  end
end

def process_sass infile
  process_file infile, :new_ext => 'css' do |source| 
    engine = Sass::Engine.new(source, :syntax => :scss)
    engine.render
  end
end




puts "Now watching #{SETTINGS[:source_dir]}/"
puts "Press CTRL-C to quit"
puts "-------------"

# watch templates
watch path_regex(:folder => SETTINGS[:template_dir], :extension => 'html.erb') do |md|
  notify md[0], :note, 'changed'
  Dir[SETTINGS[:source_dir]+'/**/*.*'].each do |file|
    process_markdown file
  end
end

# watch markdown files
watch path_regex(:extension => 'markdown') do |md|
  process_markdown md[0]
end

# watch sass files
watch path_regex(:extension => 'scss') do |md|
  process_sass md[0]
end

# watch css files
watch path_regex(:extension => 'css') do |md|
  dst = destination_of(md[0])
  FileUtils.mkdir_p File.dirname(dst)
  FileUtils.copy md[0], dst
  notify md[0], :message, 'copy'
end

