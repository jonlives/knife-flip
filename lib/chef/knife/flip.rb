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

      puts "Looking for #{@node_name}"

      searcher = Chef::Search::Query.new
      result = searcher.search(:node, "name:#{@node_name}")

      knife_search = Chef::Knife::Search.new
      node = result.first.first
      if node.nil?
        puts "Could not find a node named #{@node_name}"
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
      knife_search.name_args = ['node', "name:#{@node_name}"]
      knife_search.run

    end
  end
end
