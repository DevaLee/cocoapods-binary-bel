module Pod
    class Command
      class Install < Command
        @@use_source = false
        def self.options
          [
            ['--hsource', 'from cocoapods-binary-bel, all frameworks use source code'],
          ].concat(super).reject { |(name, _)| name == '--no-repo-update' }
        end
  
        def initialize(argv)
          super
          @@use_source = argv.flag?('hsource', false)
        end

        def self.all_use_source
            @@use_source
        end

        def self.run(argv)
            super(argv)
        end

        
      end
    end
end
  