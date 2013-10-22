module Mongoid
  module Elasticsearch
    class Es
      attr_reader :klass, :version

      def initialize(klass)
        @klass = klass
        @version = Gem::Version.new(client.info['version']['number'])
      end

      def client
        # dup is needed because Elasticsearch::Client.new changes options hash inplace
        @client ||= ::Elasticsearch::Client.new klass.es_client_options.dup
      end

      def index
        @index ||= Index.new(self)
      end

      def search(query, options = {})
        if query.is_a?(String)
          query = {q: Utils.clean(query)}
        end

        page = options[:page]
        options[:per_page] ||= 50
        per_page = options[:per_page]

        query[:size] = ( per_page.to_i ) if per_page
        query[:from] = ( page.to_i <= 1 ? 0 : (per_page.to_i * (page.to_i-1)) ) if page && per_page

        Response.new(client, query.merge(type_options(true)), false, klass, klass.es_wrapper, options)
      end

      def all(options = {})
        search({match_all: {}}, options)
      end

      def options_for(obj, escape = false)
        {id: obj.id.to_s}.merge type_options(escape)
      end

      def type_options(escape = false)
        if Elasticsearch::VERSION < '0.4.1'
          {index: index.name, type: escape ? Utils.escape(index.type) : index.type}
        else
          {index: index.name, type: index.type}
        end
      end

      def index_item(obj)
        client.index({body: obj.as_indexed_json}.merge(options_for(obj, true)))
      end

      def remove_item(obj)
        client.delete(options_for(obj, true).merge(ignore: 404))
      end

      def completion_supported?
        @version > Gem::Version.new('0.90.2')
      end

      def completion(text, field = "suggest")
        raise "Completion not supported in ES #{@version}" unless completion_supported?
        body = {
          q: {
            text: Utils.clean(text),
            completion: {
              field: field
            }
          }
        }
        results = client.suggest(index: index.name, body: body)
        results['q'][0]['options']
      end
    end
  end
end
