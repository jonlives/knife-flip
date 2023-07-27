#
# Author:: Jon Cowie (<jonlives@gmail.com>)
# Copyright:: Copyright (c) 2011 Jon Cowie
# License:: GPL


require 'chef/knife'

module KnifeFlip
  class EnvironmentFlip < Chef::Knife

    deps do
      require 'chef/search/query'
      require 'chef/knife/search'
    end

    banner "knife environment flip ENV_FROM ENV_TO"

    def run
      unless @old_env = name_args[0]
        ui.error "You need to specify an environment to search against"
        exit 1
      end

      unless @new_env = name_args[1]
        ui.error "You need to specify an environment to move nodes to"
        exit 1
      end

      puts "Checking for a environment called #{@old_env} to flip nodes from..."

      searcher = Chef::Search::Query.new
      result = searcher.search(:environment, "name:#{@old_env}")

      env = result.first.first
      if env.nil?
        puts "Could not find an environment named #{@old_env}. Can't update nodes in a non-existant environment!"
        exit 1
      else
        puts "Found!\n"
      end


      puts "Checking for an environment called #{@new_env} to update to..."

      searcher = Chef::Search::Query.new
      result = searcher.search(:environment, "name:#{@new_env}")

      env = result.first.first
      if env.nil?
        puts "Could not find an environment named #{@new_env}. Please create it before trying to put nodes in it!"
        exit 1
      else
        puts "Found!\n"
      end

      q_nodes = Chef::Search::Query.new
      node_query = "chef_environment:#{@old_env}"
      query_nodes = URI::Parser.new.escape(node_query,
                               Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

      result_items = []
      result_count = 0

      #ui.msg("\nFinding all nodes in environment #{@old_env} and moving them to environment #{@new_env}...\n")

      begin
        q_nodes.search('node', query_nodes) do |node_item|

          node_item.chef_environment(@new_env)
          node_item.save
          formatted_item_node = format_for_display(node_item)
          if formatted_item_node.respond_to?(:has_key?) && !formatted_item_node.has_key?('id')
            formatted_item_node.normal['id'] = node_item.has_key?('id') ? node_item['id'] : node_item.name
          end
          ui.msg("Moving #{formatted_item_node.name} to environment #{@new_env}...")
          result_items << formatted_item_node
          result_count += 1
        end
      rescue Net::HTTPServerException => e
        msg = Chef::JSONCompat.from_json(e.response.body)["error"].first
        ui.error("knife role flip failed: #{msg}")
        exit 1
      end

      if ui.interchange?
        output({:results => result_count, :rows => result_items})
      else
        ui.msg "#{result_count} Nodes updated"
      end

    end
  end
end
