## Based on https://gist.github.com/961827 by nstielau


require 'chef/knife'
require 'colorize'

module KnifeFlip
  class NodeFlip < Chef::Knife

    deps do
      require 'chef/search/query'
      require 'chef/knife/search'
      require 'chef/knife/core/object_loader'
    end

    banner "knife node flip NODE ENVIRONMENT (options)"

    option :preview,
      :long => '--preview',
      :boolean => true,
      :on => :tail,
      :description => 'Preview the target environment to see affected cookbooks'

    def run
      unless @node_name = name_args[0]
        ui.error "You need to specify a node"
        exit 1
      end

      unless @environment = name_args[1]
        ui.error "You need to specify an environment"
        exit 1
      end

      if config[:preview] then
        show_environmental_differences
      else
        puts "Looking for an fqdn of #{@node_name} or name of #{@node_name}"

        searcher = Chef::Search::Query.new
        result = searcher.search(:node, "fqdn:#{@node_name} OR name:#{@node_name}")

        knife_search = Chef::Knife::Search.new
        node = result.first.first
        if node.nil?
          puts "Could not find a node with the fqdn of #{@node_name} or name of #{@node_name}"
          exit 1
        end

        begin
          e = Chef::Environment.load(@environment)
        rescue Net::HTTPServerException => e
          if e.response.code.to_s == "404"
            ui.error "The environment #{@environment} does not exist on the server, aborting."
            Chef::Log.debug(e)
            exit 1
          else
             raise
          end
        end
    
        puts "Setting environment to #{@environment}"
        node.chef_environment(@environment)
        node.save

        knife_search = Chef::Knife::Search.new
        # ensure that 'start' and 'rows' are set since we don't seem to properly inherit the +config+ hash and therefore don't get sane defaults
        config[:start] = 0
        config[:rows] = 1000
        knife_search.config = config  # without this, the +config+ hash is empty
        knife_search.name_args = ['node', "fqdn:#{@node_name} OR name:#{@node_name}"]
        knife_search.run
      end
    end

    private

    # Compare the two environments
    def show_environmental_differences
      # Re-iterate to the user that this won't flip you
      remind_user_about_preview

      # Load up the node information
      load_node_object

      # Get the source environment
      get_source_environment

      # Pull down the cookbooks for this node
      cookbooks = get_cookbooks_for_node

      # Get cookbooks for the environments we are checking
      source_cookbooks = cookbooks_for_environment(@source_environment)
      target_cookbooks = cookbooks_for_environment(@environment)

      # Transform the uploaded cookbooks into a name => latest version hash
      source_hash = get_cookbook_version_hash(source_cookbooks)

      # Transform the production cookbooks into a name => latest version hash
      target_hash = get_cookbook_version_hash(target_cookbooks)

      # Intersect the production cookbook collection and ours
      common_cookbooks = target_cookbooks.keys & cookbooks
      changed_cookbooks = common_cookbooks.keep_if { |cookbook_key| 
        target_hash[cookbook_key] != source_hash[cookbook_key] 
      }
      
      # Lets show what is different
      show_cookbook_differences(changed_cookbooks, source_hash, target_hash)
    end

    # Load up the node in question into a instance variable
    def load_node_object
      searcher = Chef::Search::Query.new
      result = searcher.search(:node, "fqdn:#{@node_name} OR name:#{@node_name}")

      @node = result.first.first
      if @node.nil?
        puts "Could not find a node with the fqdn of #{@node_name} or name of #{@node_name}"
        exit 1
      end      
    end

    # Extract the source environment from the node object
    def get_source_environment
      @source_environment = @node.chef_environment
    end

    # For the node being passed in, find and return an array of cookboock names
    def get_cookbooks_for_node
      cookbooks = @node.recipes.map {|recipe| recipe.match('^[^:]+')[0] }.uniq

      return cookbooks
    end

    # For an environment, get all the cookbooks associated with it (in API object array form)
    def cookbooks_for_environment(environment=nil, num_versions=1)
      api_endpoint = environment ? "/environments/#{environment}/cookbooks?#{num_versions}" : "/cookbooks?#{num_versions}"
      cookbooks = rest.get_rest(api_endpoint)
      
      return cookbooks        
    end

    # Given a cookbook array returned from the API, create a Hash of its name and the latest version
    def get_cookbook_version_hash(cookbooks)
      Hash[cookbooks.collect { |k, v| [k, v['versions'].first['version']] }]  
    end

    # Takes in an array of modified cookbook names, the hash of uploaded cookbooks, and the hash of cookbooks
    # from the environment being checked
    def show_cookbook_differences(changed_cookbook_names, source_hash, target_hash)
      changed_cookbook_count = changed_cookbook_names.size
      (1..110).each { print "=".colorize(:cyan) }
      puts ""
      if changed_cookbook_count != 0 then
        puts "#{changed_cookbook_count} difference(s) between environments"
        changed_cookbook_names.each do |cookbook_name|
          puts "#{cookbook_name}".colorize(:yellow) + ": " + "#{@source_environment}".colorize(:magenta) +
               " version: " + "#{source_hash[cookbook_name]} ".colorize(:red) +
               "will be changed to " + "#{target_hash[cookbook_name]}".colorize(:green) + " in " +
               "#{@environment}".colorize(:magenta)
        end
      elsif (@source_environment == @environment) and (changed_cookbook_names.size == 0) then
        puts "The environment the node is on and the one you are flipping to are identical, and thus "
        puts "there are " + "NO".colorize(:red) +" cookbook differences"
      else
        puts "No differences".colorize(:red) +
              " between the cookbook versions in the " + "#{@source_environment}".colorize(:magenta) + " and the " +
              "#{@environment}".colorize(:magenta) + " environment for this node"
      end
      (1..110).each { print "=".colorize(:cyan) }
      puts ""
    end

    # Print out warning for users so they know that preview is a dry run
    def remind_user_about_preview
      puts "NOTE NOTE NOTE".colorize(:red) + " Running with --preview " + "WILL NOT".colorize(:red) +
           " flip your node\n"
    end
  end
end
