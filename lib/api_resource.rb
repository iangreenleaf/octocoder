module ApiResource
  def api_request url, opts={}
    Typhoeus::Request.new url, prepare_opts(opts)
  end

  protected
  def prepare_opts opts
    opts = opts.dup
    opts[:params] ||= {}
    opts[:params] = opts[:params].merge secret
    opts
  end

  def secret
    @secret ||=
      begin
        YAML.load_file 'config/github_keys.yml'
      rescue
        {}
      end
  end
end
