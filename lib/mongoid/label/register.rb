module Mongoid
  module LabelRegister
    extend ActiveSupport::Concern
 
    module ClassMethods
      def register_labels(*args)
        options = args.extract_options!
        label_field = (args.blank? ? :labels : args.shift).to_sym
        register_field = "#{label_field}_register".to_sym
        
        field register_field, :type => Hash
        
        #instace methods
        class_eval <<-END
          def #{label_field}_weight(label_name)
            get_weight_for(:#{label_field}, label_name)
          end
          
          def #{label_field}_with_weight
            get_all_weights_for(:#{label_field})
          end
        END
      end
    end
    
    module InstanceMethods
      def increment_register_for(label_field, str, val)
        register = get_register(label_field)
        return if !register && val < 0 #should not happen
        register = {} unless register
        if register[str]
          register[str][:count] += val
        else
          if val < 0
            register[str] = {:count => 0}
          else
            register[str] = {:count => 1}
          end
        end
        set_register(label_field, register)
      end
      
      def get_weight_for(label_field, label_name)
        register = get_register(label_field)
        return 0 unless register
        return 0 unless register[label_name]
        return register[label_name][:count]
      end
      
      def get_all_weights_for(label_field)
        result = []
        register = get_register(label_field)
        return [] unless register
        register.keys.each do |key|
          result << [key, register[key][:count]]
        end
        return result
      end
      
      def set_register(field, register)
        self.send(:"#{field}_register=", register)
        save
      end
      
      def get_register(field)
        self.send(:"#{field}_register")
      end
    end
  end
end