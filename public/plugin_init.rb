# my_routes = [File.join(File.dirname(__FILE__), "routes.rb")]
# ArchivesSpace::Application.config.paths['config/routes'].concat(my_routes)
my_app_dir = File.dirname(__FILE__)

# prefer my assets over the ArchivesSpace PUI defaults
my_assets = File.join(my_app_dir, "assets")
ArchivesSpacePublic::Application.config.paths['app/assets'].unshift(my_assets)

# puts "*** >>> #{ArchivesSpacePublic::Application.config.inspect} <<< ***"

ArchivesSpacePublic::Application.config.after_initialize do

  # Application
  # class Application
  #   puts "*** >>> #{self.config.inspect} <<< ***"
  # end

  # Force the module to load
  # todo:
  ApplicationHelper
  module ApplicationHelper

    def title_or_finding_aid_filing_title_with_ids(resource)
      display_id_prefix(resource) + title_or_finding_aid_filing_title(resource)
    end

    def display_id_prefix(resource, sep='-', prefix='[', suffix=']')
      id_string = display_id(resource, sep=sep)
      prefix + id_string + suffix + ' '
    end

    def display_id(resource, sep='-')
      (['id_0', 'id_1', 'id_2', 'id_3'].collect{|attr| resource[attr]} - ['', nil]).join(sep)
    end

    def repository_list
      repos = archivesspace.list_repositories
      repos.update(repos){ |uri, _| info = parse_repository_info(archivesspace.get_record(uri).json) }
      repos
    end

    def parse_repository_info(repository)
      # this is just a paramerterized version of public/app/models/record.rb:parse_repository_info()
      info = {}
      info['top'] = {}
      unless repository.nil?
        %w(name uri url parent_institution_name image_url repo_code).each do | item |
          info['top'][item] = repository[item] unless repository[item].blank?
        end
        unless repository['agent_representation'].blank? || repository['agent_representation']['_resolved'].blank? || repository['agent_representation']['_resolved']['jsonmodel_type'] != 'agent_corporate_entity'
          in_h = repository['agent_representation']['_resolved']['agent_contacts'][0]
          %w{city region post_code country email }.each do |k|
            info[k] = in_h[k] if in_h[k].present?
          end
          if in_h['address_1'].present?
            info['address'] = []
            [1,2,3].each do |i|
              info['address'].push(in_h["address_#{i}"]) if in_h["address_#{i}"].present?
            end
          end
          info['telephones'] = in_h['telephones'] if !in_h['telephones'].blank?
        end
      end
      info
    end

    private

    def archivesspace
      ArchivesSpaceClient.instance
    end



  end


  Resource
  class Resource
    # from public/app/models/resource.rb
    def breadcrumb
      [
          {
              :uri => '',
              :type => 'resource',
              :crumb => display_string,
              :id => 'woo-hoo',
          }
      ]
    end

  end

  ArchivesSpaceClient
  class ArchivesSpaceClient

    def get(uri, params = {})
      url = build_url(uri, params=params)
      request = Net::HTTP::Get.new(url)
      Rails.logger.debug("GET url: #{url}")
      response = do_http_request(request)
      if response.code != '200'
        Rails.logger.debug("Code: #{response.code}")
        raise RequestFailedException.new("#{response.code}: #{response.body}")
      end
      results = JSON.parse(response.body)
    end

  end

  # monkey patch Hash
  # class Hash
  #   def method_missing(name, *args, &blk)
  #     if self.keys.map(&:to_sym).include? name.to_sym
  #        return self[name.to_sym]
  #      else
  #        super
  #      end
  #   end
  # end

  TreeNodes
  module TreeNodes
    # include JHUPublic
    # include display_id

    # puts "*** About to dump JHUPublic ***"
    # puts "#{JHUPublic.inspect}"
    # puts "#{JHUPublic::display_id}"

    def breadcrumb
      crumbs = []

      # @raw contains the object with some resolved entities
      # @raw['_resolved_resource'] contains:
      #   {"/repositories/4/resources/1164"=>[{
      #     "title"=>"Lester Dequaine collection on Rosa Ponselle", "publish"=>true, "id_0"=>"PIMS", "id_1"=>"0004",
      #     "level"=>"collection", "uri"=>"/repositories/4/resources/1164"}]}
      # @resolved_resource also contains this information (w/o the uri as a key)
      #   {"title"=>"Lester Dequaine collection on Rosa Ponselle", "publish"=>true, "id_0"=>"PIMS", "id_1"=>"0004",
      #     "level"=>"collection", "uri"=>"/repositories/4/resources/1164"}
      # @raw['json'] contains the json chunk for the object
      # @uri contains this object URI
      # @level contains the level ("collection", "series", "subseries", etc.)

      # puts "*** >>> uri >> #{@uri} <<< ***"
      # puts "*** >>> object >>> #{@raw['json']} <<< ***"
      # add all ancestors to breadcrumb
      path_to_root.each_with_index do |node, level|
        # puts "*** >>> #{level.inspect} >>> #{node.inspect} <<< ***"
        crumbs << {
            :uri => breadcrumb_uri_for_node(node),
            :type => node['jsonmodel_type'],
            :crumb => breadcrumb_title_for_node(node, level)
        }
      end
      # puts "*** >>> crumbs: #{crumbs.inspect} <<<"

      # and now yourself
      crumbs << {
          :uri => '',
          :type => primary_type,
          :crumb => display_string
      }
      # puts "*** >>> crumbs: #{crumbs.inspect} <<<"

      process_mixed_content("blah blah blah")

      tree = resource_tree
      children = tree["children"]
      crumbs.each_with_index do |crumb, index|
        # puts "*** >>> index=#{index} crumb=#{crumb} <<< ***"
        if index > 0
          # puts "*** >>> tree before: #{tree} <<< ***"
          matches = children.select { |child|  [crumb[:uri], @uri].include?(child["record_uri"]) }
          if matches.length == 1
            match = matches[0]
            crumb[:level] = match["level"]
            children = match["children"]
          end
        else
          crumb[:identifier] = display_id(@resolved_resource)
          crumb[:level] = @resolved_resource["level"]
        end
      end

      crumbs
    end

    def resource_tree
      begin
        base_url = "#{root_node_uri}/tree"
        search_opts = {:limit_to => @uri}
        # puts "*** >>> search_opts >>> #{search_opts} <<<"
        result = archives_space_client.get(base_url, params=search_opts)
        result
      rescue RecordNotFound => e
        $stderr.puts "RecordNotFound: #{url}"
        {}
      end
    end

    def display_id(resource, sep='-')
      (['id_0', 'id_1', 'id_2', 'id_3'].collect{|attr| resource[attr]} - ['', nil]).join(sep)
    end

  end


  ResourcesController
  class ResourcesController

    def show
      uri = "/repositories/#{params[:rid]}/resources/#{params[:id]}"
      begin
        @criteria = {}
        @criteria['resolve[]']  = ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id', 'related_accession_uris:id', 'digital_object_uris:id']

        tree_root = archivesspace.get_raw_record(uri + '/tree/root') rescue nil
        @has_children = tree_root && tree_root['child_count'] > 0
        @has_containers = has_containers?(uri)

        @result =  archivesspace.get_record(uri, @criteria)
        @repo_info = @result.repository_information
        @page_title = "#{I18n.t('resource._singular')}: #{strip_mixed_content(@result.display_string)}"
        # @context = [{:uri => @repo_info['top']['uri'], :crumb => @repo_info['top']['name']}, {:uri => nil, :crumb => "xxx #{@result.identifier} #{process_mixed_content(@result.display_string)}"}]
        @context = resource_breadcrumb
        #      @rep_image = get_rep_image(@result['json']['instances'])
        fill_request_info
      rescue RecordNotFound
        @type = I18n.t('resource._singular')
        @page_title = I18n.t('errors.error_404', :type => @type)
        @uri = uri
        @back_url = request.referer || ''
        render  'shared/not_found', :status => 404
      end
    end

    def infinite
      @root_uri = "/repositories/#{params[:rid]}/resources/#{params[:id]}"
      begin
        @criteria = {}
        @criteria['resolve[]']  = ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id', 'related_accession_uris:id']
        @result =  archivesspace.get_record(@root_uri, @criteria)
        @has_containers = has_containers?(@root_uri)

        @repo_info = @result.repository_information
        @page_title = "#{I18n.t('resource._singular')}: #{strip_mixed_content(@result.display_string)}"
        # @context = [{:uri => @repo_info['top']['uri'], :crumb => @repo_info['top']['name']}, {:uri => nil, :crumb => "yyy [#{@result.identifier}] #{process_mixed_content(@result.display_string)}"}]
        @context = resource_breadcrumb
        fill_request_info
        @ordered_records = archivesspace.get_record(@root_uri + '/ordered_records').json.fetch('uris')
      rescue RecordNotFound
        @type = I18n.t('resource._singular')
        @page_title = I18n.t('errors.error_404', :type => @type)
        @uri = @root_uri
        @back_url = request.referer || ''
        render  'shared/not_found', :status => 404
      end
    end

    def inventory
      uri = "/repositories/#{params[:rid]}/resources/#{params[:id]}"

      tree_root = archivesspace.get_raw_record(uri + '/tree/root') rescue nil
      @has_children = tree_root && tree_root['child_count'] > 0

      begin
        # stuff for the collection bits
        @criteria = {}
        @criteria['resolve[]']  = ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id', 'related_accession_uris:id']
        @result =  archivesspace.get_record(uri, @criteria)
        @repo_info = @result.repository_information
        @page_title = "#{I18n.t('resource._singular')}: #{strip_mixed_content(@result.display_string)}"
        # @context = [{:uri => @repo_info['top']['uri'], :crumb => @repo_info['top']['name']}, {:uri => nil, :crumb => "zzz [#{@result.identifier}] #{process_mixed_content(@result.display_string)}"}]
        @context = resource_breadcrumb
        fill_request_info

        # top container stuff ... sets @records
        fetch_containers(uri, "#{uri}/inventory", params)

        if !@results.blank?
          params[:q] = '*'
          @pager =  Pager.new(@base_search, @results['this_page'], @results['last_page'])
        else
          @pager = nil
        end

      rescue RecordNotFound
        @type = I18n.t('resource._singular')
        @page_title = I18n.t('errors.error_404', :type => @type)
        @uri = uri
        @back_url = request.referer || ''
        render  'shared/not_found', :status => 404
      end
    end

    def resource_breadcrumb
      [
          {:uri => @repo_info['top']['uri'], :crumb => @repo_info['top']['name'], :level => "Repository", :type => "repository"},
          {:uri => nil, :crumb => process_mixed_content(@result.display_string),
           :identifier => @result.identifier, :level => "collection", :type => "resource"}
      ]

    end

  end

    # todo: now ResourcesController?
  # todo: instance variable is @context? public/app/controllers/resources_controller.rb in search() and show()
=begin
  RecordsController
  class RecordsController

    def resource
      resource = JSONModel(:resource).find(params[:id], :repo_id => params[:repo_id], "resolve[]" => ["subjects", "container_locations", "digital_object", "linked_agents", "related_accessions"])
      raise RecordNotFound.new if (!resource || !resource.publish)
      @resource = ResourceView.new(resource)
      breadcrumb_title = title_or_finding_aid_filing_title_with_ids(resource)

      @breadcrumbs = [
          [@repository['repo_code'], url_for(:controller => :search, :action => :repository, :id => @repository.id), "repository"],
          [breadcrumb_title, "#", "resource"]
      ]
    end


   # todo: now AccessionsController?
   # todo: instance variable is @context?
   # todo: instance variable is @context? public/app/controllers/accessions_controller.rb:85-87 in show()
   # AccessionsController
   # class AccessionsController
    def archival_object
      archival_object = JSONModel(:archival_object).find(params[:id], :repo_id => params[:repo_id], "resolve[]" => ["subjects", "container_locations", "digital_object", "linked_agents"])
      raise RecordNotFound.new if (!archival_object || archival_object.has_unpublished_ancestor || !archival_object.publish)

      @archival_object = ArchivalObjectView.new(archival_object)
      @tree_view = Search.tree_view(@archival_object.uri)


      @breadcrumbs = [
          [@repository['repo_code'], url_for(:controller => :search, :action => :repository, :id => @repository.id), "repository"]
      ]

      @tree_view["path_to_root"].each do |record|
        raise RecordNotFound.new if not record["publish"] == true

        if record["node_type"] === "resource"
          resource = JSONModel(:resource).find(record["id"], :repo_id => params[:repo_id])
          raise RecordNotFound.new if (!resource || !resource.publish)

          @resource_uri = record['record_uri']
          breadcrumb_title = title_or_finding_aid_filing_title_with_ids(resource)
          @breadcrumbs.push([breadcrumb_title, url_for(:controller => :records, :action => :resource, :id => record["id"], :repo_id => @repository.id), "resource"])
        else
          @breadcrumbs.push([record["title"], url_for(:controller => :records, :action => :archival_object, :id => record["id"], :repo_id => @repository.id), "archival_object"])
        end
      end

      @breadcrumbs.push([@archival_object.display_string, "#", "archival_object"])
    end

  end
=end
end

