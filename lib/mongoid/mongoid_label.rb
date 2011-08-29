module Mongoid
  module Label
    extend ActiveSupport::Concern
    
    included do
      class_attribute :label_options
      self.label_options = {}
      

      set_callback :save,     :after, :update_label_register
#      set_callback :destroy,  :before, :store_referances
      set_callback :destroy,  :after, :decrement_register
      

    end
    
    module ClassMethods
      def labels(*args)
        options = args.extract_options!
        label_field = (args.blank? ? :labels : args.shift).to_sym
        
        label_collection = "#{label_field}_collection".to_sym

        field label_field, :type => String, :default => ""
        embeds_many label_collection, :as => :labelable
        
        options.reverse_merge!(
          :register_in => nil
        )
        
        # register / update settings
        class_options = label_options || {}
        class_options[label_field] = options
        self.label_options = class_options
        
        # instance methods
        class_eval <<-END
          def #{label_field}=(s)
            super
            set_labels_from_string(:#{label_field}, s)
          end
        END
      end
    end
    
    module InstanceMethods
      
      def label_collection_from_field(field)
        self.send(:"#{field}_collection")
      end
      
      def set_labels_from_string(label_field, str)
        label_strings = str.split(",").map(&:strip).uniq.compact
        label_item_strings = label_collection_from_field(label_field).collect{|label_item| label_item.name}
       
        #
        # delete those that have been removed
        #
        label_item_strings.each do |str|
          delete_label_from_string(label_field, str) unless label_strings.include?(str)
        end
        
        #
        # add new labels
        #
        label_strings.each do |str|
          add_label_from_string(label_field, str) unless label_item_strings.include?(str)
        end
      end
      
      def delete_label_from_string(label_field, str)
        label_collection_from_field(label_field).delete_if{|item| item.name == str}
      end
      
      def add_label_from_string(label_field, str)
        label_collection_from_field(label_field) << Mongoid::Label::Item.new(:name => str)
      end
      
      def label_contexts
        label_options.keys
      end
      
      def label_register(register_symbol)
        self.send register_symbol
      end
      
      def update_label_register
        return unless self.changed?
        label_contexts.each do |context|
          register = label_options[context][:register_in]
          return unless register
          changes = self.changes["#{context}"]
          if changes
            old_labels = changes[0].split(",").map(&:strip)
            new_labels = changes[1].split(",").map(&:strip)
            added_labels = new_labels - old_labels
            removed_labels = old_labels - new_labels
            
            added_labels.each do |label|
              label_register(register).increment_register_for(context, label, 1)
            end
            
            removed_labels.each do |label|
              label_register(register).increment_register_for(context, label, -1)
            end
          end
        end
      end
      
      def decrement_register
        label_contexts.each do |context|
          register = label_options[context][:register_in]
          return unless register
          labels = self.send context
          labels.split(",").map(&:strip).each do |label|
            label_register(register).increment_register_for(context, label, -1)
          end
        end
      end
    end
  end
end
