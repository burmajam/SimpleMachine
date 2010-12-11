module StateMachine
  def self.included(klass)
    klass.extend ClassMethods
  end
  
  class StateMachinePrototype
    def initialize(owner)
      @owner = owner
    end
    
    def all_states
      self.class.all_states
    end
    def allowed_transitions
      current_state = @owner.send self.class.parents_state_field_name
      result = self.class.defined_transitions[current_state].collect { |hash| hash[:transition] }
      result.collect do |transition|
        guard_method = "guard_for_#{transition}_on_#{self.class.parents_state_field_name}".to_sym
        transition if !@owner.respond_to?( guard_method ) or @owner.send(guard_method)
      end.compact
    end
    
    class << self
      attr_accessor :parents_state_field_name
      attr_reader :all_states, :defined_transitions
      attr_writer :owner_class
      
      def initial_state(state)
        @all_states = [] << state
        variable = "@#{@parents_state_field_name}_default_state"
        @owner_class.instance_eval { instance_variable_set(variable, state) }
      end
      def other_states(*other_states)
        @all_states = @all_states | other_states
      end
      def allow_transition(transition, options)
        @defined_transitions ||= {}
        raise "Unknown source state #{options[:from]}. Please define it first as initial_state or in other_states." unless all_states.include?(options[:from])
        raise "Unknown target state #{options[:to]}. Please define it first as initial_state or in other_states." unless all_states.include?(options[:to])
        
        @defined_transitions[options[:from]] = [] unless @defined_transitions.has_key?(options[:from])
        @defined_transitions[options[:from]] << { :transition => transition, :target_state => options[:to] }     
        
        class_eval do
          define_method "can_#{transition}?" do
            allowed_transitions.include? transition
          end
          define_method transition do
            current_state = @owner.send self.class.parents_state_field_name
            if self.class.defined_transitions[current_state].inject(false) { |memo, hash| memo or hash[:transition] == transition }
              raise "Unable to #{transition.to_s.gsub '_', ' '} due to guard"
            else
              raise "Invalid transition ##{transition.to_s.gsub '_', ' '} from '#{current_state}' state"
            end unless allowed_transitions.include? transition
            variable = "@#{self.class.parents_state_field_name}"
            @owner.instance_eval { instance_variable_set variable, options[:to] }
          end
        end   
      end
    end
  end

  module ClassMethods
      
    def implement_state_machine_for(state_field_name, &block)
      machine_property_name = "#{state_field_name}_machine".to_sym
      default_state_field_name = "#{state_field_name}_default_state".to_sym

      define_method state_field_name do
        result = instance_variable_get "@#{state_field_name}"
        result = instance_variable_set "@#{state_field_name}", self.class.send(default_state_field_name) unless result
        result
      end
      define_method machine_property_name do
        result = instance_variable_get "@#{machine_property_name}"
        result = instance_variable_set "@#{machine_property_name}", StateMachine::ClassMethods.get_state_machine_class_for(self, state_field_name).new(self) unless result
        result
      end
      self.class.class_eval do
        define_method default_state_field_name do
          instance_variable_get "@#{default_state_field_name}"
        end
      end
      
      StateMachine::ClassMethods.get_state_machine_class_for(self, state_field_name).instance_eval &block
      
      raise "Initial state not defined." unless send default_state_field_name
    end
    
    private
    
    @state_machine_classes = {}
    
    def self.get_state_machine_class_for(cls, state_field_name)
      unless @state_machine_classes.has_key? state_field_name
        @state_machine_classes[state_field_name] ||= StateMachine::StateMachinePrototype.clone
        @state_machine_classes[state_field_name].owner_class = cls
        @state_machine_classes[state_field_name].parents_state_field_name = state_field_name
      end
      @state_machine_classes[state_field_name]
    end
  end
end
