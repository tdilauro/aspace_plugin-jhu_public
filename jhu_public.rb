module JHUPublic
  extend ActiveSupport::Concern

  def display_id_prefix(resource, sep='.', prefix='[', suffix=']')
    id_string = display_id(resource, sep=sep)
    prefix + id_string + suffix + ' '
  end

  def display_id(resource, sep='.')
    (['id_0', 'id_1', 'id_2', 'id_3'].collect{|attr| resource[attr]} - ['', nil]).join(sep)
  end

  def repository_list
    repos = archivesspace.list_repositories
    repos.update(repos){ |uri, _| info = parse_repository_info(archivesspace.get_record(uri).json) }
    repos
  end

end
