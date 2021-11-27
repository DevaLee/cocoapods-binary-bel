require_relative 'rome/build_framework'
require_relative 'helper/passer'
require_relative 'helper/target_checker'
require 'cfpropertylist'




# patch prebuild ability
module Pod
    class Installer

        include Config::Mixin
        
        private

        def local_manifest 
            if not @local_manifest_inited
                @local_manifest_inited = true
                raise "This method should be call before generate project" unless self.analysis_result == nil
                @local_manifest = self.sandbox.manifest
            end
            @local_manifest
        end
         # @return [Analyzer::SpecsState]
        def prebuild_pods_changes
            # return nil if local_manifest.nil?
            # if @prebuild_pods_changes.nil?
            #     changes = local_manifest.detect_changes_with_podfile(podfile)
            #     @prebuild_pods_changes = Analyzer::SpecsState.new(changes)
            #     # save the chagnes info for later stage
            #     Pod::Prebuild::Passer.prebuild_pods_changes = @prebuild_pods_changes 
            # end
            # @prebuild_pods_changes


            return nil if local_manifest.nil?
            # if @prebuild_pods_changes.nil?
                changes = local_manifest.detect_changes_with_podfile(podfile)

                unchanged_pod_names = changes[:unchanged]
                changed_pod_names = changes[:changed]

                unchanged_pod_names.reverse_each do |name|
                    mainfest_pod_version = local_manifest.version(name).to_s
                    already_prebuild_version = prebuilded_framework_version(name) || "未找到"
                    if already_prebuild_version != mainfest_pod_version 

                        Pod::UI.puts("- #{name} 已编译版本 #{already_prebuild_version}, manifest中的版本: #{mainfest_pod_version}") if config.verbose
                        
                       changed_pod_names = changed_pod_names.push(name)
                       unchanged_pod_names.delete(name)
                    end
                end

                changes[:changed] = changed_pod_names
                changes[:unchanged] = unchanged_pod_names

                Pod::UI.puts("需要重编译的framework : #{changed_pod_names.to_s}") if config.verbose
                changed_pod_names.each do |name|
                    self.sandbox.delete_old_version_prebuilded_framework(name)
                end
                @prebuild_pods_changes = Analyzer::SpecsState.new(changes)
                # save the chagnes info for later stage
                Pod::Prebuild::Passer.prebuild_pods_changes = @prebuild_pods_changes 
            # elsif

            # end
            @prebuild_pods_changes
        end
       

        
        public 

        def post_update_build_changed
            # 无任何change
            changes = lockfile.detect_changes_with_podfile(podfile)
            unchanged_pod_names = changes[:unchanged]
            changed_pod_names = changes[:changed]

            Pod::UI.puts("检查已编译的版本是否和 Podile.lock 中的版本是否一致")
            unchanged_pod_names.reverse_each do |name|
                mainfest_pod_version = lockfile.version(name).to_s
                already_prebuild_version = prebuilded_framework_version(name) || "未找到"
                if already_prebuild_version != mainfest_pod_version 

                    Pod::UI.puts("- #{name} 已编译版本 #{already_prebuild_version}, manifest中的版本: #{mainfest_pod_version}") if config.verbose
                        
                    changed_pod_names = changed_pod_names.push(name)
                    unchanged_pod_names.delete(name)
                end
            end

            changes[:changed] = changed_pod_names
            changes[:unchanged] = unchanged_pod_names

            Pod::UI.puts("需要重编译的framework : #{changed_pod_names.to_s}") if config.verbose

            @prebuild_pods_changes = Analyzer::SpecsState.new(changes)
            # save the chagnes info for later stage
            Pod::Prebuild::Passer.prebuild_pods_changes = @prebuild_pods_changes 

            prebuild_frameworks!

        end
        
        # check if need to prebuild
        def have_exact_prebuild_cache?

            # check if need build frameworks
            return false if local_manifest == nil 
        
            changes = prebuild_pods_changes
            added = changes.added
            changed = changes.changed 
            unchanged = changes.unchanged
            deleted = changes.deleted 
            
            exsited_framework_pod_names = sandbox.exsited_framework_pod_names
            missing = unchanged.select do |pod_name|
                not exsited_framework_pod_names.include?(pod_name)
            end

            needed = (added + changed + deleted + missing) 

            return needed.empty?
        end
        # 当前已编译的framework的版本
        def prebuilded_framework_version(name)
            path = self.sandbox.plist_path_for_target_name(name)
            framework_version = ""
            if Pathname.new(path).exist?
                plist_file = CFPropertyList::List.new(:file => path) 
                data = CFPropertyList.native_types(plist_file.value)
                framework_version = data["CFBundleShortVersionString"]
            end
            framework_version
        end
        

        # The install method when have completed cache
        def install_when_cache_hit!
            # just print log
            self.sandbox.exsited_framework_target_names.each do |name|
                UI.puts "Using #{name}"
            end
        end
    

        # Build the needed framework files
        def prebuild_frameworks! 
            # build options
            sandbox_path = sandbox.root
            existed_framework_folder = sandbox.generate_framework_path
            bitcode_enabled = Pod::Podfile::DSL.bitcode_enabled
            targets = []
            
            if local_manifest != nil

                changes = prebuild_pods_changes
                added = changes.added
                changed = changes.changed 
                unchanged = changes.unchanged
                deleted = changes.deleted 
    
                existed_framework_folder.mkdir unless existed_framework_folder.exist?
                exsited_framework_pod_names = sandbox.exsited_framework_pod_names
    
                # additions
                missing = unchanged.select do |pod_name|
                    not exsited_framework_pod_names.include?(pod_name)
                end


                root_names_to_update = (added + changed + missing)

                # transform names to targets
                cache = []
                targets = root_names_to_update.map do |pod_name|
                    tars = Pod.fast_get_targets_for_pod_name(pod_name, self.pod_targets, cache)
                    if tars.nil? || tars.empty?
                        raise "There's no target named (#{pod_name}) in Pod.xcodeproj.\n #{self.pod_targets.map(&:name)}" if t.nil?
                    end
                    tars
                end.flatten

                # add the dendencies
                dependency_targets = targets.map {|t| t.recursive_dependent_targets }.flatten.uniq || []
                targets = (targets + dependency_targets).uniq
            else
                targets = self.pod_targets
            end

            targets = targets.reject {|pod_target| sandbox.local?(pod_target.pod_name) }

            
            # build!
            Pod::UI.puts "Prebuild frameworks (total #{targets.count})"
            Pod::Prebuild.remove_build_dir(sandbox_path)
            targets.each do |target|
                if !target.should_build?
                    UI.puts "Prebuilding #{target.label}"
                    next
                end

                output_path = sandbox.framework_folder_path_for_target_name(target.name)
                output_path.rmtree if output_path.exist?
                output_path.mkpath unless output_path.exist?
                Pod::Prebuild.build(sandbox_path, target, output_path, bitcode_enabled,  Podfile::DSL.custom_build_options,  Podfile::DSL.custom_build_options_simulator)

                # save the resource paths for later installing
                if target.static_framework? and !target.resource_paths.empty?
                    framework_path = output_path + target.framework_name
                    standard_sandbox_path = sandbox.standard_sanbox_path

                    resources = begin
                        if Pod::VERSION.start_with? "1.5"
                            target.resource_paths
                        else
                            # resource_paths is Hash{String=>Array<String>} on 1.6 and above
                            # (use AFNetworking to generate a demo data)
                            # https://github.com/leavez/cocoapods-binary/issues/50
                            target.resource_paths.values.flatten
                        end
                    end
                    raise "Wrong type: #{resources}" unless resources.kind_of? Array

                    path_objects = resources.map do |path|
                        object = Prebuild::Passer::ResourcePath.new
                        object.real_file_path = framework_path + File.basename(path)
                        object.target_file_path = path.gsub('${PODS_ROOT}', standard_sandbox_path.to_s) if path.start_with? '${PODS_ROOT}'
                        object.target_file_path = path.gsub("${PODS_CONFIGURATION_BUILD_DIR}", standard_sandbox_path.to_s) if path.start_with? "${PODS_CONFIGURATION_BUILD_DIR}"
                        object
                    end
                    Prebuild::Passer.resources_to_copy_for_static_framework[target.name] = path_objects
                end

            end            
            Pod::Prebuild.remove_build_dir(sandbox_path)


            # copy vendored libraries and frameworks
            targets.each do |target|
                root_path = self.sandbox.pod_dir(target.name)
                target_folder = sandbox.framework_folder_path_for_target_name(target.name)
                
                # If target shouldn't build, we copy all the original files
                # This is for target with only .a and .h files
                if not target.should_build? 
                    Prebuild::Passer.target_names_to_skip_integration_framework << target.name
                    FileUtils.cp_r(root_path, target_folder, :remove_destination => true)
                    next
                end

                target.spec_consumers.each do |consumer|
                    file_accessor = Sandbox::FileAccessor.new(root_path, consumer)
                    lib_paths = file_accessor.vendored_frameworks || []
                    lib_paths += file_accessor.vendored_libraries
                    # @TODO dSYM files
                    lib_paths.each do |lib_path|
                        relative = lib_path.relative_path_from(root_path)
                        destination = target_folder + relative
                        destination.dirname.mkpath unless destination.dirname.exist?
                        FileUtils.cp_r(lib_path, destination, :remove_destination => true)
                    end
                end
            end

            # save the pod_name for prebuild framwork in sandbox 
            targets.each do |target|
                sandbox.save_pod_name_for_target target
            end
            
            # Remove useless files
            # remove useless pods
            all_needed_names = self.pod_targets.map(&:name).uniq
            useless_target_names = sandbox.exsited_framework_target_names.reject do |name| 
                all_needed_names.include? name
            end
            useless_target_names.each do |name|
                path = sandbox.framework_folder_path_for_target_name(name)
                path.rmtree if path.exist?
            end

            if not Podfile::DSL.dont_remove_source_code 
                # only keep manifest.lock and framework folder in _Prebuild
                to_remain_files = ["Manifest.lock", File.basename(existed_framework_folder)]
                to_delete_files = sandbox_path.children.select do |file|
                    filename = File.basename(file)
                    not to_remain_files.include?(filename)
                end
                to_delete_files.each do |path|
                    path.rmtree if path.exist?
                end
            else 
                # just remove the tmp files
                path = sandbox.root + 'Manifest.lock.tmp'
                path.rmtree if path.exist?
            end
        end


        # old_method3 = instance_method(:perform_post_install_actions)
        # define_method(:perform_post_install_actions) do
        #     Pod::UI.puts(">>>>>>>>>>>>>> pod update 检查 spec 依赖 是否有改动")
        

        #     standard_sandbox = self.sandbox
        #     prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(standard_sandbox)
            
        #     # get the podfile for prebuild
        #     prebuild_podfile = Pod::Podfile.from_ruby(podfile.defined_in_file)
            
        #     # install
        #     lockfile = self.lockfile
        #     binary_installer = Pod::Installer.new(prebuild_sandbox, prebuild_podfile, lockfile)
        #     binary_installer.remove_target_files_if_needed
        #     binary_installer.post_update_build_changed

        #     old_method3.bind(self).()
        # end
        
        # patch the post install hook
        old_method2 = instance_method(:run_plugins_post_install_hooks)
        define_method(:run_plugins_post_install_hooks) do 
            old_method2.bind(self).()
            if Pod::is_prebuild_stage
                self.prebuild_frameworks!
            end
        end


    end
end