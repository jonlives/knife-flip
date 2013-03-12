## Based on https://gist.github.com/961827 by nstielau


require 'chef/knife'

module KnifeFlip
  class NodeFlip < Chef::Knife

    deps do
      require 'chef/search/query'
      require 'chef/knife/search'
      require 'chef/knife/core/object_loader'
    end

    banner "knife node flip NODE ENVIRONMENT"

    def run
      unless @node_name = name_args[0]
        ui.error "You need to specify a node"
        exit 1
      end

      unless @environment = name_args[1]
        ui.error "You need to specify an environment"
        exit 1
      end

      puts "Looking for an fqdn of #{@node_name}"

      searcher = Chef::Search::Query.new
      result = searcher.search(:node, "fqdn:#{@node_name}")

      knife_search = Chef::Knife::Search.new
      node = result.first.first
      if node.nil?
        puts "Could not find a node with the fqdn of #{@node_name}"
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
      knife_search.name_args = ['node', "fqdn:#{@node_name}"]
      knife_search.run

    end
  end
end
