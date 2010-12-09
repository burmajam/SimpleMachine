require 'rubygems'
require 'rspec'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../lib/state_machine')

RSpec.configure do |config|
  config.mock_with :mocha
end


class Job
  include StateMachine  
  # implement_state_machine_for :dispatch_status do
  #   initial_state :waiting
  #   other_states :assigned, :accepted, :cancelled, :closed
  #   allow_transition :assign, :from => :waiting, :to => :assigned
  #   allow_transition :reject, :from => :assigned, :to => :waiting
  # end
end

describe StateMachine, "on :dispatch_status field" do
  context "without initial state" do
    it "raises exception that initial state is undefined" do
      lambda { Job.implement_state_machine_for :dispatch_status do; end }.should( raise_error do |e|
        e.message.should match("Initial state not defined: Job.dispatch_status_default_state is null")
      end )
    end
  end
  context "with initial state :waiting" do
    before :each do
      Job.implement_state_machine_for :dispatch_status do
        Job.initial_state :waiting
      end
    end
    
    it "defines :waiting as initial state" do
      Job.dispatch_status_default_state.should == :waiting
    end
    
    it "#dispatch_status is :waiting" do
      Job.new.dispatch_status.should == :waiting
    end
    
    it "has 1 state" do
      Job.instance_eval do
        @_all_states.size.should == 1
      end
    end
    
    context "when :assigned, :accepted, :cancelled and :closed states are defined also" do
      before :each do
        Job.other_states :assigned, :accepted, :cancelled, :closed
      end
        
      it "has 5 states" do
        Job.instance_eval { @_all_states.size.should == 5 }
      end
      it "knows which 5 states are defined" do
        Job.instance_eval { @_all_states.should == [:waiting, :assigned, :accepted, :cancelled, :closed] }
      end
      
      context "for defined :assign transition from :waiting to :assigned" do
        before :each do
          Job.allow_transition :assign, :from => :waiting, :to => :assigned
        end
        
        it "returns :assign as allowed transitions when in :waiting state" do
          job = Job.new
          
          job.should have(1).allowed_transitions
          job.allowed_transitions.should include(:assign)
        end
        it "doesn't return :assign as allowed transition if guard_for_assign returns false" do
          Job.any_instance.stubs(:guard_for_assign).returns false
          
          job = Job.new
          
          job.should have(0).allowed_transitions
        end
        it "returns :assign as allowed transition if guard_for_assign returns true" do
          Job.any_instance.stubs(:guard_for_assign).returns true
          
          job = Job.new
          
          job.allowed_transitions.should include(:assign)
        end
        describe "#assign transition" do
          context "when it is allowed" do
            it "sets #dispatch_status to :assigned" do
              Job.any_instance.stubs(:allowed_transitions).returns([:assign])
              
              job = Job.new
              job.assign
            
              job.dispatch_status.should be(:assigned)
            end
          end
          context "when it is not valid transition from current state" do
            it "raises an error" do
              Job.allow_transition :reject, :from => :assigned, :to => :waiting
            
              job = Job.new
              lambda { job.reject }.should( raise_error do |e|
                e.message.should match("Invalid transition #reject from 'waiting' state")
              end )
            end
          end
          context "when it is not valid transition right now" do
            it "raises an error" do
              Job.allow_transition :assign, :from => :waiting, :to => :assigned
              Job.any_instance.stubs(:guard_for_assign).returns false
            
              job = Job.new
              lambda { job.assign }.should( raise_error do |e|
                e.message.should match("Unable to assign due to guard")
              end )
            end
          end
        end
      end
      describe "transition guards" do
        it "responds as true for #can_go_back? if :go_back is allowed transition" do
          Job.allow_transition :go_back, :from => :assigned, :to => :waiting
          Job.any_instance.stubs(:allowed_transitions).returns [:go_back, :something, :else]
          
          job = Job.new
          
          job.allowed_transitions.should include(:go_back)
          job.can_go_back?.should be_true
        end
        it "responds as false for #can_go_back? if :go_back is not allowed transition but is defined" do
          Job.allow_transition :go_back, :from => :assigned, :to => :waiting
          Job.any_instance.stubs(:allowed_transitions).returns [:anything, :but, :not_go_back]
          
          job = Job.new
          
          job.allowed_transitions.should_not include(:go_back)
          job.can_go_back?.should be_false
        end
        it "raises an error for #can_do_something_undefined? if :do_something_undefined is not defined transition" do
          lambda { Job.new.can_do_something_undefined? }.should( raise_error do |e|
            e.message.should include("undefined method `can_do_something_undefined?' for #<Job:")
          end )
        end
      end
    end
  end
end
