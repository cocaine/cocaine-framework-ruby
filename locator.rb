class Config
  attr_reader :services

  def initialize
    @services = {
        :locator => {
            :port => 10053,
            :state => :init,
            :states => {
                :init => {
                    [0, ['node']] => [
                        [:send, [0, ['localhost, 20001'], 1, {}]],
                        [:send, [2, []]],
                        [:drop, []]
                    ]
                }
            }
        }
    }
  end
end