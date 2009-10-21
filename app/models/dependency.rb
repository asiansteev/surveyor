class Dependency < ActiveRecord::Base
  # Associations
  belongs_to :question
  belongs_to :question_group
  has_many :dependency_conditions
  
  # Scopes
  named_scope :depending_on_questions, lambda {|question_ids| {:joins => :dependency_conditions, :conditions => {:dependency_conditions => {:question_id => question_ids}} }}
  
  # Validations
  validates_presence_of :rule
  validates_format_of :rule, :with => /^(?:and|or|\)|\(|[A-Z]|\s)+$/ #TODO properly formed parenthesis etc.
  validates_numericality_of :question_id, :if => Proc.new { |d| d.question_group_id.nil? }
  validates_numericality_of :question_group_id, :if => Proc.new { |d| d.question_id.nil? }
  
  # Attribute aliases
  alias_attribute :dependent_question_id, :question_id
  
  def question_group_id=(i)
    write_attribute(:question_id, nil) unless i.nil?
    write_attribute(:question_group_id, i)
  end
  
  def question_id=(i)
    write_attribute(:question_group_id, nil) unless i.nil?
    write_attribute(:question_id, i) 
  end
  
  # Is the method that determines if this dependency has been met within
  # the provided response set
  def met?(response_set)
    if keyed_pairs = keyed_conditions(response_set)
      return(rule_evaluation(keyed_pairs))
    else
      return(false)
    end
  end

  # Pairs up the substitution key with the evaluated condition result for substitution into the rule
  # Example: If you have two dependency conditions with rule keys "A" and "B" in the rule "A or B"
  # calling keyed_condition_pairs will return {:A => true, :B => false}
  def keyed_conditions(response_set)
    keyed_pairs = {}
    # logger.debug dependency_conditions.inspect
    self.dependency_conditions.each do |dc|
      keyed_pairs.merge!(dc.to_evaluation_hash(response_set))
    end
    return(keyed_pairs)
  end

  # Does the substiution and evaluation of the dependency rule with the keyed pairs
  def rule_evaluation(keyed_pairs)
    # subtitute into rule for evaluation
    rgx = Regexp.new(self.dependency_conditions.map{|dc| ["a","o"].include?(dc.rule_key) ? "#{dc.rule_key}(?!nd|r)" : dc.rule_key}.join("|")) # Making a regexp to only look for the keys used in the child conditions
    # logger.debug "rule: #{self.rule.inspect}"
    # logger.debug "rexp: #{rgx.inspect}"
    # logger.debug "keyp: #{keyed_pairs.inspect}"
    # logger.debug "subd: #{self.rule.gsub(rgx){|m| keyed_pairs[m.to_sym]}}"
    eval(self.rule.gsub(rgx){|m| keyed_pairs[m.to_sym]}) # returns the evaluation of the rule and the conditions
  end
  
end
