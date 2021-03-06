module God
  module CLI
    
    class Run
      def initialize(options)
        @options = options
        
        dispatch
      end
      
      def dispatch
        # have at_exit start god
        $run = true
        
        # run
        if @options[:daemonize]
          run_daemonized
        else
          run_in_front
        end
      end
      
      def attach
        process = System::Process.new(@options[:attach])
        Thread.new do
          loop do
            unless process.exists?
              applog(nil, :info, "Going down because attached process #{@options[:attach]} exited")
              exit!
            end
            sleep 5
          end
        end
      end
      
      def run_daemonized
        # trap and ignore SIGHUP
        Signal.trap('HUP') {}
        
        pid = fork do
          begin
            require 'god'
            
            log_file = @options[:log] || "/dev/null"
            
            # reset file descriptors
            STDIN.reopen "/dev/null"
            STDOUT.reopen(log_file, "a")
            STDERR.reopen STDOUT
            STDOUT.sync = true
            
            # start attached pid watcher if necessary
            if @options[:attach]
              self.attach
            end
            
            # set port if requested
            if @options[:port]
              God.port = @options[:port]
            end
            
            # set pid if requested
            if @options[:pid]
              God.pid = @options[:pid] 
            end
            
            unless @options[:syslog]
              Logger.syslog = false
            end
            
            if @options[:events]
              God::EventHandler.load
            end
            
            unless God::EventHandler.loaded?
              puts
              puts "***********************************************************************"
              puts "*"
              puts "* Event conditions are not available for your installation of god."
              puts "* You may still use and write custom conditions using the poll system"
              puts "*"
              puts "***********************************************************************"
              puts
            end
            
            # load config
            if @options[:config]
              # set log level, defaults to WARN
              if @options[:log_level]
                God.log_level = @options[:log_level]
              else
                God.log_level = :warn
              end
              
              unless File.exist?(@options[:config])
                abort "File not found: #{@options[:config]}"
              end
              
              # start the event handler
              God::EventHandler.start if God::EventHandler.loaded?
              
              begin
                load File.expand_path(@options[:config])
              rescue Exception => e
                if e.instance_of?(SystemExit)
                  raise
                else
                  puts e.message
                  puts e.backtrace.join("\n")
                  abort "There was an error in your configuration file (see above)"
                end
              end
            end
          rescue => e
            puts e.message
            puts e.backtrace.join("\n")
            abort "There was a fatal system error while starting god (see above)"
          end
        end
        
        if @options[:pid]
          File.open(@options[:pid], 'w') { |f| f.write pid }
        end
        
        ::Process.detach pid
        
        exit
      end
      
      def run_in_front
        require 'god'
        
        if @options[:bleakhouse]
          BleakHouseDiagnostic.install
        end
        
        # start attached pid watcher if necessary
        if @options[:attach]
          self.attach
        end
        
        if @options[:port]
          God.port = @options[:port]
        end
        
        if @options[:events]
          God::EventHandler.load
        end
        
        # set log level if requested
        if @options[:log_level]
          God.log_level = @options[:log_level]
        end
        
        if @options[:config]
          unless File.exist?(@options[:config])
            abort "File not found: #{@options[:config]}"
          end
          
          # start the event handler
          God::EventHandler.start if God::EventHandler.loaded?
          
          begin
            load File.expand_path(@options[:config])
          rescue Exception => e
            if e.instance_of?(SystemExit)
              raise
            else
              puts e.message
              puts e.backtrace.join("\n")
              abort "There was an error in your configuration file (see above)"
            end
          end
          
          if @options[:log]
            log_file = File.expand_path(@options[:log])
            puts "Sending output to log file: #{log_file}"
            
            # reset file descriptors
            STDIN.reopen "/dev/null"
            STDOUT.reopen(log_file, "a")
            STDERR.reopen STDOUT
            STDOUT.sync = true
          end
        end
      end
    end # Run
    
  end
end