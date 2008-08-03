require 'ec2onrails/version'

AUTHOR = ['Paul Dowman', 'Adam Greene']  # can also be an array of Authors
EMAIL = "paul@pauldowman.com"
DESCRIPTION = "Client-side libraries (Capistrano tasks) for managing and deploying to EC2 on Rails servers."
GEM_NAME = 'ec2onrails' # what ppl will type to install your gem
RUBYFORGE_PROJECT = 'ec2onrails' # The unix name for your project
HOMEPATH = "http://#{RUBYFORGE_PROJECT}.rubyforge.org"
DOWNLOAD_PATH = "http://rubyforge.org/projects/#{RUBYFORGE_PROJECT}"

@config_file = "~/.rubyforge/user-config.yml"
@config = nil
RUBYFORGE_USERNAME = "unknown"
def rubyforge_username
  unless @config
    begin
      @config = YAML.load(File.read(File.expand_path(@config_file)))
    rescue
      puts <<-EOS
ERROR: No rubyforge config file found: #{@config_file}
Run 'rubyforge setup' to prepare your env for access to Rubyforge
 - See http://newgem.rubyforge.org/rubyforge.html for more details
      EOS
      exit
    end
  end
  RUBYFORGE_USERNAME.replace @config["username"]
end


REV = nil 
# UNCOMMENT IF REQUIRED: 
# REV = `svn info`.each {|line| if line =~ /^Revision:/ then k,v = line.split(': '); break v.chomp; else next; end} rescue nil
VERS = Ec2onrails::VERSION::STRING + (REV ? ".#{REV}" : "")
RDOC_OPTS = ['--quiet', '--title', 'ec2onrails documentation',
    "--opname", "index.html",
    "--line-numbers", 
    "--main", "README.textile",
    "--inline-source"]

class Hoe
  def extra_deps 
    @extra_deps.reject! { |x| Array(x).first == 'hoe' } 
    @extra_deps
  end 
end

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
hoe = Hoe.new(GEM_NAME, VERS) do |p|
  p.author = AUTHOR 
  p.description = DESCRIPTION
  p.email = EMAIL
  p.summary = DESCRIPTION
  p.url = HOMEPATH
  p.rubyforge_name = RUBYFORGE_PROJECT if RUBYFORGE_PROJECT
  p.test_globs = ["test/**/test_*.rb"]
  p.clean_globs |= ['**/.*.sw?', '*.gem', '.config', '**/.DS_Store']  #An array of file patterns to delete on clean.
  
  # == Optional
  p.changes = p.paragraphs_of("CHANGELOG", 0..1).join("\\n\\n")
  # An array of rubygem dependencies [name, version], e.g. [ ['active_support', '>= 1.3.1'] ]
  p.extra_deps = [['capistrano', '= 2.4.3'], ['archive-tar-minitar', '>= 0.5.1'], ['optiflag', '>= 0.6.5']]     
  
  #p.spec_extras = {}    # A hash of extra values to set in the gemspec.
  
end

CHANGES = hoe.paragraphs_of('CHANGELOG', 0..1).join("\\n\\n")
PATH    = (RUBYFORGE_PROJECT == GEM_NAME) ? RUBYFORGE_PROJECT : "#{RUBYFORGE_PROJECT}/#{GEM_NAME}"
hoe.remote_rdoc_dir = File.join(PATH.gsub(/^#{RUBYFORGE_PROJECT}\/?/,''), 'rdoc')