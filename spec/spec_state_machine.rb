require 'rubygems'
require 'rspec'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../lib/state_machine')

RSpec.configure { |config| config.mock_with :mocha }

describe StateMachine, "for :dispatch_state field on Job, when state machine is aready defined for :other_state on Job and for :dispatch_state on Driver" do
  before :all do
    class Driver
      include StateMachine
      implement_state_machine_for :dispatch_state do
        initial_state :waiting
        other_states :assigned, :circling, :going_to_pickup_location, :on_pickup_location, :driving_passenger, :changing_zone, :going_home
        allow_transition :assign, :from => :waiting, :to => :assigned
      end
    end
    class Job
      include StateMachine  
      implement_state_machine_for :other_state do
        initial_state :created
        other_states :deleted, :reviewed, :done, :closed
        allow_transition :delete, :from => :created, :to => :deleted
        allow_transition :delete, :from => :reviewed, :to => :deleted
      end
      # following commented out lines will be tested:
      #
      # implement_state_machine_for :dispatch_state do
      #   initial_state :waiting
      #   other_states :assigned, :cancelled
      #   allow_transition :assign, :from => :waiting, :to => :assigned
      #   allow_transition :cancel, :from => :waiting, :to => :cancelled
      #   allow_transition :reject, :from => :assigned, :to => :waiting
      # end
      #
      # def guard_for_cancel_on_dispatch_state; false; end
    end

    # Job.dispatch_state_default_state => :waiting
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
  end
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
      Job.dispatch_state_default_state.should be(:waiting)
    end    
    it "sets dispatch_status to :waiting on new job" do
      Job.new.dispatch_state.should be(:waiting)
    end

    describe "#dispatch_state_machine on job " do
      it "#all_states contains only :waiting" do
        all_states = Job.new.dispatch_state_machine.all_states
      
        all_states.size.should == 1
        all_states.should include(:waiting)
      end    
    end
  end  

  context "when initial :waiting and other :assigned, :accepted, :cancelled and :closed states are defined also" do
    before :all do
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
        it "doesn't contain :assign if job#guard_for_assign_on_dispatch_state returns false" do
          Job.any_instance.stubs(:guard_for_assign_on_dispatch_state).returns false
        
          Job.new.dispatch_state_machine.should have(0).allowed_transitions
        end
        it "contains :assign if job#guard_for_assign_on_dispatch_state returns true" do
          Job.any_instance.stubs(:guard_for_assign_on_dispatch_state).returns true
        
          Job.new.dispatch_state_machine.allowed_transitions.should include(:assign)
        end
        it "raises exception if there's attempt to define again :assign transition from :waiting state" do
          @inner_state_machine_class = Job.new.dispatch_state_machine.class
          lambda { @inner_state_machine_class.allow_transition :assign, :from => :waiting, :to => :closed }.should( raise_error do |e|
            e.message.should match("Already defined transition 'assign' from 'waiting' state")
          end )
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
          it "calls job#after_dispatch_state_changed callback if defined" do
            Job.any_instance.expects(:after_dispatch_state_changed)
            Job.new.dispatch_state_machine.assign
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
        context "when it is not valid transition due to guard method" do
          it "raises an error" do
            Job.any_instance.stubs(:guard_for_assign_on_dispatch_state).returns false
          
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
  context "when there are more job instances" do
    before :all do
      Job.implement_state_machine_for :dispatch_state do
        allow_transition :accept, :from => :assigned, :to => :accepted
      end
    end
    
    it "each instance tracks it's own flow" do
      job1 = Job.new
      job2 = Job.new
      
      job1.dispatch_state_machine.assign
      job2.dispatch_state_machine.assign
      job2.dispatch_state_machine.accept
      
      job1.dispatch_state.should be(:assigned)
      job2.dispatch_state.should be(:accepted)
    end
  end
end
