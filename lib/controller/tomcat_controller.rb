%w(jenkins_controller log_watcher).each { |f| require File.dirname(__FILE__)+"/"+f }

# Runs Jenkins on Tomcat
#
# @attr [String] opts
#    specify the location of jenkins.war
# @attr [String] catalina_home
#    specify the location of Tomcat installation 
class TomcatController < JenkinsController
  register :tomcat
  JENKINS_DEBUG_LOG = Dir.pwd + "/last_test.log"

  def initialize(opts)
    @war = opts[:war] || ENV['JENKINS_WAR'] || File.expand_path("./jenkins.war")
    raise "jenkins.war doesn't exist in #{@war}, maybe you forgot to set JENKINS_WAR env var? "  if !File.exists?(@war)

    @catalina_home = opts[:catalina_home] || ENV['CATALINA_HOME'] || File.expand_path("./tomcat")
    raise "#{@catalina_home} doesn't exist, maybe you forgot to set CATALINA_HOME env var or provide catalina_home parameter? "  if !File.directory?(@catalina_home)

    @tempdir = TempDir.create(:rootpath => Dir.pwd)
    
    FileUtils.rm JENKINS_DEBUG_LOG if File.exists? JENKINS_DEBUG_LOG
    @log = File.open(JENKINS_DEBUG_LOG, "w")

    @base_url = "http://127.0.0.1:8080/jenkins/"
  end

  def start!
    ENV["JENKINS_HOME"] = @tempdir
    puts
    print "    Bringing up a temporary Jenkins/Tomcat instance\n"

    FileUtils.rm_rf("#{@catalina_home}/webapps/jenkins") if Dir.exists?("#{@catalina_home}/webapps/jenkins")
    FileUtils.rm("#{@catalina_home}/webapps/jenkins.war") if File.exists?("#{@catalina_home}/webapps/jenkins.war")
    FileUtils.cp(@war,"#{@catalina_home}/webapps")
    @tomcat_log = "#{@catalina_home}/logs/catalina.out" 
    FileUtils.rm @tomcat_log if File.exists?(@tomcat_log)

    @is_running = system("#{@catalina_home}/bin/startup.sh")
    raise "Cannot start Tomcat" if !@is_running
   
    @pipe = IO.popen("tail -f #{@tomcat_log}")
    @log_watcher = LogWatcher.new(@pipe,@log)
    @log_watcher.wait_for_ready
  end

  def stop!
    puts
    print "    Stopping a temporary Jenkins/Tomcat instance\n"
    @is_running = !system("#{@catalina_home}/bin/shutdown.sh");
    raise "Cannot stop Tomcat" if @is_running
  end

  def teardown
    unless @log.nil?
      @log.close
    end
    FileUtils.rm_rf(@tempdir)
  end

  def url
    @base_url
  end

  def diagnose
    puts "It looks like the test failed/errored, so here's the console from Jenkins:"
    puts "--------------------------------------------------------------------------"
    File.open(JENKINS_DEBUG_LOG, 'r') do |fd|
      fd.each_line do |line|
        puts line
      end
    end
  end
end
