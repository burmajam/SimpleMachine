module StateMachine
  def self.included(klass)
    klass.extend ClassMethods
  end
  
  module ClassMethods
    def implement_state_machine_for(state_field_name, &block)
      default_state_field_name = "#{state_field_name}_default_state".to_sym
      state_field_variable_name = "@#{state_field_name}".to_sym
      default_state_field_variable_name = "@#{default_state_field_name}".to_sym

      @_transition_definitions = {}
      @_all_states = []
      
      define_method state_field_name do
        instance_variable_get( state_field_variable_name ) || self.class.send(default_state_field_name)
      end
      
      define_method :allowed_transitions do
        current_state = self.send(state_field_name)
        result = self.class.instance_eval { @_transition_definitions }[current_state].collect { |hash| hash[:transition] }
        result.collect do |transition|
          guard_method = "guard_for_#{transition}".to_sym
          transition if !respond_to?( guard_method ) or send(guard_method)
        end.compact
      end

      self.class.class_eval do
        attr_reader default_state_field_name
        
        define_method :initial_state do |initial_state|
          @_all_states << initial_state
          instance_variable_set default_state_field_variable_name, initial_state
        end
        define_method :other_states do |*other_states|
          @_all_states = @_all_states | other_states
        end
        define_method :defined_transitions do
          @_transition_definitions
        end
        define_method :allow_transition do |transition, options|
          raise "Unknown source state #{options[:from]}. Please define it first as initial_state or in other_states." unless @_all_states.include?(options[:from])
          raise "Unknown target state #{options[:to]}. Please define it first as initial_state or in other_states." unless @_all_states.include?(options[:to])
          @_transition_definitions[options[:from]] = [] unless @_transition_definitions.has_key?(options[:from])
          @_transition_definitions[options[:from]] << { :transition => transition, :target_state => options[:to] }
          class_eval do
            define_method "can_#{transition}?" do
              allowed_transitions.include? transition
            end
            define_method transition do
              if self.class.defined_transitions[send state_field_name].inject(false) { |memo, hash| memo or hash[:transition] == transition }
                raise "Unable to #{transition.to_s.gsub '_', ' '} due to guard"
              else
                raise "Invalid transition ##{transition.to_s.gsub '_', ' '} from '#{send state_field_name}' state"
              end unless allowed_transitions.include? transition
              instance_variable_set state_field_variable_name, options[:to]
            end
          end
        end
      end

      yield
      
      raise "Initial state not defined: #{self}.#{default_state_field_name} is null" unless send(default_state_field_name)
    end
  end
end
