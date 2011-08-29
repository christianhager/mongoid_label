module Mongoid
  module Label
    extend ActiveSupport::Concern
    
    included do
      class_attribute :label_options
      self.label_options = {}
      set_callback :save,     :after, :update_label_register
      set_callback :destroy,  :after, :decrement_register
    end
    
    module ClassMethods
      def labels(*args)
        options = args.extract_options!
        label_field = (args.blank? ? :labels : args.shift).to_sym
        
        field label_field, :type => String, :default => ""
        field :"#{label_field}_collection", :type => Array, :default => []
        options.reverse_merge!(
          :register_in => nil
        )
        
        # register / update settings
        class_options = label_options || {}
        class_options[label_field] = options
        self.label_options = class_options
        
        #
        # scopes
        #
        scope :"with_#{label_field}", lambda { |names| names = names.to_a unless names.is_a?(Array);all_in(:"#{label_field}_collection" => names)}
        scope :"without_#{label_field}", lambda { |names| names = names.to_a unless names.is_a?(Array);not_in(:"#{label_field}_collection" => names)}
        scope :"with_any_#{label_field}", lambda { |names| names = names.to_a unless names.is_a?(Array);any_in(:"#{label_field}_collection" => names)}
        
        # instance methods
        class_eval <<-END
          def #{label_field}=(s)
            super
            arr = s.split(",").map(&:strip).uniq.compact
            write_attribute(:#{label_field}, arr.join(","))
            write_attribute(:#{label_field}_collection, arr)
          end
          
          def remove_#{label_field}(labels)
            _remove_labels(:#{label_field}, labels)
          end
          
          def add_#{label_field}(labels)
            _add_labels(:#{label_field}, labels)
          end
        END
      end
    end
    
    module InstanceMethods
      
      def _add_labels(label_field, labels)
        labels = labels.to_a unless labels.is_a?(Array)
        puts "#{self.send(label_field).split(",").map(&:strip)} + #{labels.map(&:strip)} = #{(self.send(label_field).split(",").map(&:strip) + labels.map(&:strip)).uniq.compact.join(",")}"
        new_label_str = (self.send(label_field).split(",").map(&:strip) + labels.map(&:strip)).uniq.compact.join(",")
        self.send(:"#{label_field}=", new_label_str)
      end
      
      def _remove_labels(label_field, labels)
        labels = labels.to_a unless labels.is_a?(Array)
        puts "#{self.send(label_field).split(",").map(&:strip)} - #{labels.map(&:strip)} = #{(self.send(label_field).split(",").map(&:strip) - labels.map(&:strip)).uniq.compact.join(",")}"
        new_label_str = (self.send(label_field).split(",").map(&:strip) - labels.map(&:strip)).uniq.compact.join(",")
        self.send(:"#{label_field}=", new_label_str)
      end
      
      def label_collection_from_field(field)
        self.send(:"#{field}_collection")
      end
      
      def set_labels_from_string(label_field, str)
        
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
