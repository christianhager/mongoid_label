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
    end
    
    it "should add a new label to an exsisting collection" do
      @m.labels = "car, blue, imported"
      @m.labels_collection[0].should == "car"
      @m.labels_collection[1].should == "blue"
      @m.labels_collection[2].should == "imported"
      @m.labels = "car, blue, imported, sold"
      @m.labels_collection[0].should == "car"
      @m.labels_collection[1].should == "blue"
      @m.labels_collection[2].should == "imported"
      @m.labels_collection[3].should == "sold"
    end
    
    it "should remove labels from collection that have been removed" do
      @m.labels = "car, blue, imported"
      @m.labels_collection.size.should == 3
      @m.labels = "car, imported"
      @m.labels_collection.size.should == 2
      @m.labels_collection[0].should == "car"
      @m.labels_collection[1].should == "imported"
    end
    
    it "should remove whitespace" do
      @m.labels = "car       , blue,     imported"
      @m.labels_collection[0].should == "car"
      @m.labels_collection[1].should == "blue"
      @m.labels_collection[2].should == "imported"
    end
    
    it "should work for named labels as well" do
      @m.system_labels = "traced, Out of Stock"
      @m.labels_collection.size.should == 0
      @m.system_labels_collection.size.should == 2

      @m.system_labels_collection[0].should == "traced"
      @m.system_labels_collection[1].should == "Out of Stock"
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
   
   context "getting weight from label register" do
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
   
   context "scope labels" do
     before(:each) do
       @register = Register.create
       @m1 = M2.new(:register => @register, :labels => "bread, juice, sugar")
       @m2 = M2.new(:register => @register, :labels => "bread, milk, tea")
       @m3 = M2.new(:register => @register, :labels => "loaf, juice, sugar")
      @m1.save; @m2.save; @m3.save!
     end
     
     it "should find models labeled with a label" do
       @register.models.with_labels("bread").should == [@m1, @m2]
       p @register.models.with_labels(["juice", "sugar"])
       @register.models.with_labels(["juice", "sugar"]).should == [@m1, @m3]
       @register.models.with_labels(["juice", "sugar", "whatever"]).should == []
     end
     
     it "should find models not labeled with a label" do
       @register.models.without_labels("bread").should == [@m3]
       @register.models.without_labels(["juice", "sugar"]).should == [@m2]
     end
     
     it "should find models labeled with any label in" do
       p @register.models.with_any_labels(["bread", "whatever"])
       @register.models.with_any_labels(["bread", "whatever"]).should == [@m1, @m2]
     end
   end
   
   context "adding and removing label direct" do
     before(:each) do
       @register = Register.create
       @m1 = M2.new(:register => @register, :labels => "bread, juice, sugar, black")
       @m1.save
     end
     context "for a model" do
       it "should add one label" do
         @m1.add_labels("grey")
         @m1.save
         @m1.register.labels_weight("grey").should == 1
         @m1.labels.should == "bread,juice,sugar,black,grey"
       end
       
       it "should add multiple labels" do
         @m1.add_labels(["orange", "cute"])
         @m1.save
         @m1.labels.should == "bread,juice,sugar,black,orange,cute"
         @m1.register.labels_weight("orange").should == 1
         @m1.register.labels_weight("cute").should == 1
       end
       
       it "should ingnore existing labels" do
          @m1.register.labels_weight("black").should == 1
          @m1.add_labels("black")
          @m1.save
          @m1.register.labels_weight("black").should == 1
          @m1.labels.should == "bread,juice,sugar,black"
       end
       
       it "should remove a label" do
          @m1.remove_labels("black")
          @m1.labels.should == "bread,juice,sugar"
          @m1.save
          @m1.register.labels_weight("black").should == 0
       end
       
       it "should remove multiple labels" do
         @m1.remove_labels(["sugar", "black"])
         @m1.save
         @m1.register.labels_weight("sugar").should == 0
         @m1.register.labels_weight("black").should == 0
         
         @m1.labels.should == "bread,juice"
         
       end   
         
       it "should ignore non exsisting labels" do
         @m1.remove_labels("hello")
         @m1.save
         @m1.labels.should == "bread,juice,sugar,black"
       end
     end
     
     context "in a register" do
       it "should add label to a register with count 0"
       it "should remove a label from register and all models with that label"
       it "should remove a label from register and destroy all models with it"
       it "should update the color"
       it "should return the label with colors and weight"
     end
   end
end