# my_routes = [File.join(File.dirname(__FILE__), "routes.rb")]
# ArchivesSpace::Application.config.paths['config/routes'].concat(my_routes)

ArchivesSpacePublic::Application.config.after_initialize do

  # Force the module to load
  ApplicationHelper
  module ApplicationHelper

    def title_or_finding_aid_filing_title_with_ids(resource)
      displayIdPrefix(resource) + title_or_finding_aid_filing_title(resource)
    end

    def displayIdPrefix(resource, sep='.', prefix='[', suffix=']')
      id_string = displayId(resource, sep=sep)
      prefix + id_string + suffix + ' '
    end

    def displayId(resource, sep='.')
      (['id_0', 'id_1', 'id_2', 'id_3'].collect{|attr| resource[attr]} - ['', nil]).join(sep)
    end

  end


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
end

