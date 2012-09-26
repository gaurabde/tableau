

module ActionController #:nodoc:
  module Benchmarking
    module ClassMethods
      def benchmark(title, log_level = Logger::DEBUG, use_silence = true)
        if logger && logger.level == log_level
          result = nil
          seconds = Benchmark.realtime { result = use_silence ? silence { yield } : yield }


          ## patch for log4r from http://dev.rubyonrails.org/ticket/3512
          method_name = case log_level
                        when Logger::DEBUG
                          "debug"
                        when Logger::INFO
                          "info"
                        when Logger::WARN
                          "warn"
                        when Logger::ERROR
                          "error"
                        when Logger::FATAL
                          "fatal"
                        else
                          "fatal"
                        end
          logger.send(method_name, "#{title} (#{'%.5f' % seconds})")


          result
        else
          yield
        end
      end

    end
  end
end
