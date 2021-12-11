module Pod
    class Command
      class Install < Command
        @@use_source = false

        class << self
          alias :original_options :options
        end
        def self.options
          [['--hsource', 'from cocoapods-binaryhqp, all frameworks use source code']].concat(original_options)
        end
  
        alias :original_initialize :initialize
        def initialize(argv)
          @@use_source = argv.flag?('hsource', false)
          original_initialize(argv)
        end

        def self.all_use_source
            @@use_source
        end

        def self.set_all_use_source(use)
          @@use_source = use
        end

        
      end
    end
end

module Pod
  class Command
    class Update < Command
      class << self
        alias :original_options :options
      end
      def self.options
        [['--hsource', 'from cocoapods-binaryhqp, all frameworks use source code']].concat(original_options)
      end

      alias :original_initialize :initialize
      def initialize(argv)
        use = argv.flag?('hsource', false)
        Pod::Command::Install.set_all_use_source(use)
        original_initialize(argv)
      end
    end
  end
end
  