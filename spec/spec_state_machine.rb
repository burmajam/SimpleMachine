require 'rubygems'
require 'rspec'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../lib/state_machine')

RSpec.configure { |config| config.mock_with :mocha }

class Job
  include StateMachine  
  # implement_state_machine_for :dispatch_state do
  #   initial_state :waiting
  #   other_states :assigned, :cancelled
  #   allow_transition :assign, :from => :waiting, :to => :assigned
  #   allow_transition :cancel, :from => :waiting, :to => :cancelled
  #   allow_transition :reject, :from => :assigned, :to => :waiting
  # end
  #
  # def can_cancel?; false; end
end

# Job.dispatcn_state_default_state => :waiting
# job = Job.new
# job.dispatcn_state => :waiting
# job.dispatch_state_machine.allowed_transitions => [:assign]
# job.dispatch_state_machine.can_cancel? => false
# job.dispatch_state_machine.cancel => Exception: 'Unable to cancel due to guard'
# job.dispatch_state_machine.can_reject? => false
# job.dispatch_state_machine.reject => Exception: 'Invalid transition #reject from 'waiting' state'
# job.dispatch_state_machine.can_assign? => true
# job.dispatch_state_machine.assign => :assigned
# job.dispatcn_state => :assigned

describe StateMachine, "for :dispatch_state field on Job" do
  context "without initial state" do
    it "raises exception that initial state is undefined" do
      lambda { Job.implement_state_machine_for :dispatch_state do; end }.should( raise_error do |e|
        e.message.should match("Initial state not defined.")
      end )
    end
  end

  context "with only initial state :waiting" do
    before :each do
      Job.implement_state_machine_for :dispatch_state do
        initial_state :waiting
      end
    end
    it "defines :waiting as dispatch_state_default_state in Job" do
      Job.dispatch_state_default_state.should == :waiting
    end    
    it "sets dispatch_status to :waiting" do
      Job.new.dispatch_state.should == :waiting
    end

    describe "#dispatch_state_machine" do
      it "#all_states contains only :waiting" do
        all_states = Job.new.dispatch_state_machine.all_states
      
        all_states.should have(1).state
        all_states.should include(:waiting)
      end    
    end
  end  

  context "when initial :waiting and other :assigned, :accepted, :cancelled and :closed states are defined also" do
    before :each do
      Job.implement_state_machine_for :dispatch_state do
        initial_state :waiting
        other_states :assigned, :accepted, :cancelled, :closed
      end
    end
    it "#dispatch_state_machine#all_states has 5 states" do
      Job.new.dispatch_state_machine.all_states.should have(5).states
    end

    context "for defined :assign transition from :waiting to :assigned" do
      before :all do
        @inner_state_machine_class = Job.new.dispatch_state_machine.class
        @inner_state_machine_class.allow_transition :assign, :from => :waiting, :to => :assigned
      end
      describe "#dispatch_state_machine#allowed_transitions" do
        it "contains only :assign when in :waiting state" do
          job = Job.new
        
          job.dispatch_state_machine.should have(1).allowed_transitions
          job.dispatch_state_machine.allowed_transitions.should include(:assign)
        end
        it "doesn't contain :assign if guard_for_assign returns false" do
          Job.any_instance.stubs(:guard_for_assign).returns false
        
          Job.new.dispatch_state_machine.should have(0).allowed_transitions
        end
        it "contains :assign if guard_for_assign returns true" do
          Job.any_instance.stubs(:guard_for_assign).returns true
        
          Job.new.dispatch_state_machine.allowed_transitions.should include(:assign)
        end
      end
      describe "assign transition" do
        context "when it is allowed" do
          it "returns :assigned" do
            job = Job.new
            job.dispatch_state_machine.assign.should be(:assigned)
          end
          it "sets dispatch_state to :assigned" do
            job = Job.new
            job.dispatch_state_machine.assign
          
            job.dispatch_state.should be(:assigned)
          end
        end
        context "when it is not valid transition from current state" do
          it "raises an error" do
            @inner_state_machine_class.allow_transition :reject, :from => :assigned, :to => :waiting
          
            job = Job.new
            lambda { job.dispatch_state_machine.reject }.should( raise_error do |e|
              e.message.should match("Invalid transition #reject from 'waiting' state")
            end )
          end
        end
        context "when it is not valid transition right now" do
          it "raises an error" do
            Job.any_instance.stubs(:guard_for_assign).returns false
          
            job = Job.new
            lambda { job.dispatch_state_machine.assign }.should( raise_error do |e|
              e.message.should match("Unable to assign due to guard")
            end )
          end
        end
      end
      describe "transition guards" do
        it "#can_assign? responds as true" do
          job = Job.new
          
          job.dispatch_state_machine.allowed_transitions.should include(:assign)
          job.dispatch_state_machine.can_assign?.should be_true
        end
        it "responds as false for #can_go_back? if :go_back is not allowed transition but is defined" do
          @inner_state_machine_class.allow_transition :go_back, :from => :assigned, :to => :waiting
          
          job = Job.new
          
          job.dispatch_state_machine.allowed_transitions.should_not include(:go_back)
          job.dispatch_state_machine.can_go_back?.should be_false
        end
        it "raises an error for #can_do_something_undefined? if :do_something_undefined is not defined transition" do
          lambda { Job.new.dispatch_state_machine.can_do_something_undefined? }.should( raise_error do |e|
            e.message.should include("undefined method `can_do_something_undefined?'")
          end )
        end
      end
    end
  end
end
