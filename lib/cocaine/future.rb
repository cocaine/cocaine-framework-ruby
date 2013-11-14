class Cocaine::Future
  def set_value(value)
    @value = value
  end

  def set_error(error)
    @error = error
  end

  def get
    raise @error if @error
    @value
  end

  def self.value(value)
    f = Cocaine::Future.new
    f.set_value value
    f
  end

  def self.error(error)
    f = Cocaine::Future.new
    f.set_error error
    f
  end
end