#
# experimental routing helper
#
  


module ActionDispatch
  module Routing 
    class Mapper 
      def labels_for(*args) #:nodoc: 
        options = args.extract_options!
        options.keys.each do |key|
          register_name = options[key][:register]
          label_name = key
          controller = options[key][:controller]
          url = "/labelize/#{register_name}/#{label_name}/:tool/*#{key}"
          p url
          match url, :to => "#{controller}#labels"
        end
      end 
    end
  end 
end
