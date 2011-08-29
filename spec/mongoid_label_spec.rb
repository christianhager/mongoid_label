require 'spec_helper' 

class M1
  include Mongoid::Document
  include Mongoid::Label
  labels
  labels :system_labels
end

class M2
  include Mongoid::Document
  include Mongoid::Label
  belongs_to :register
  labels :labels, :register_in => :register
end

class Register
  include Mongoid::Document
  include Mongoid::LabelRegister
  
  has_many :models, :class_name => "M2"
  register_labels
end


describe Mongoid::Label do 
  context "saving labels from plain text" do
    before(:each) do
      @m = M1.new
    end
    
    it "should set label documents from text field" do
      @m.labels = "car, blue, imported"
      @m.labels_collection.size.should == 3
      @m.labels_collection.each{|ls| ls.should be_a(Mongoid::Label::Item)}
    end
    
    it "should add a new label to an exsisting collection" do
      @m.labels = "car, blue, imported"
      @m.labels_collection[0].name.should == "car"
      @m.labels_collection[1].name.should == "blue"
      @m.labels_collection[2].name.should == "imported"
      @m.labels = "car, blue, imported, sold"
      @m.labels_collection[0].name.should == "car"
      @m.labels_collection[1].name.should == "blue"
      @m.labels_collection[2].name.should == "imported"
      @m.labels_collection[3].name.should == "sold"
    end
    
    it "should remove labels from collection that have been removed" do
      @m.labels = "car, blue, imported"
      @m.labels_collection.size.should == 3
      @m.labels = "car, imported"
      @m.labels_collection.size.should == 2
      @m.labels_collection[0].name.should == "car"
      @m.labels_collection[1].name.should == "imported"
    end
    
    it "should remove whitespace" do
      @m.labels = "car       , blue,     imported"
      @m.labels_collection[0].name.should == "car"
      @m.labels_collection[1].name.should == "blue"
      @m.labels_collection[2].name.should == "imported"
    end
    
    it "should work for named labels as well" do
      @m.system_labels = "traced, Out of Stock"
      @m.labels_collection.size.should == 0
      @m.system_labels_collection.size.should == 2
      @m.system_labels_collection.each{|ls| ls.should be_a(Mongoid::Label::Item)}
      @m.system_labels_collection[0].name.should == "traced"
      @m.system_labels_collection[1].name.should == "Out of Stock"
    end
  end
end

describe Mongoid::LabelRegister do
   context "keeping score of labeled models" do
     before(:each) do
       register = Register.new
       @m1 = M2.new(:register => register)
       @m2 = M2.new(:register => register)
     end
     
     it "updates label count when a model gets a new label" do
       @m1.labels = "soft, clean"
       @m1.register.labels_weight("soft").should == 0
       @m1.save
       @m1.register.labels_weight("soft").should == 1
       @m2.labels = "clean"
       @m2.save
       @m1.register.labels_weight("soft").should == 1
       @m1.register.labels_weight("clean").should == 2
     end
     
     it "updates label count when a model looses a tag" do
       @m1.labels = "soft, clean"
       @m1.save
       @m1.register.labels_weight("soft").should == 1
       @m1.labels = "soft"
       @m1.save
       @m1.register.labels_weight("clean").should == 0
       @m1.labels = ""
       @m1.save
       @m1.register.labels_weight("soft").should == 0
     end
     
     it "updates label count when a model is destroyed" do
       @m1.labels = "soft, clean"
       @m1.save
       @m1.register.labels_weight("soft").should == 1
       @m1.register.labels_weight("clean").should == 1
       @m1.destroy
       @m1.register.labels_weight("soft").should == 0
       @m1.register.labels_weight("clean").should == 0
     end
   end
   
   context "getting weight from labels" do
     before(:each) do
       @m = M2.new(:register => Register.new)
     end
     it "can return a overview over all weights for all labels" do
       @m.labels = "soft, clean"
       @m.save
       @m.register.labels_with_weight.should == [
         ["soft", 1],
         ["clean", 1]
        ]
      end
   end
end