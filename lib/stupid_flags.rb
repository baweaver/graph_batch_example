# As described on the box, this is not at all meant to be a robust
# implementation of anything as much as a hyper-lazy one.
module StupidFlags
  FLAG_STATES = {
    association_loader: true
  }

  def self.enabled?(flag_name)
    FLAG_STATES.fetch(flag_name, false)
  end
end
