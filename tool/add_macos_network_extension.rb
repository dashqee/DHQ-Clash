#!/usr/bin/env ruby

require 'xcodeproj'

project_path = File.expand_path('../macos/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

runner = project.targets.find { |target| target.name == 'Runner' }
abort 'Runner target not found' unless runner

target = project.targets.find { |item| item.name == 'DHQClashNetworkExtension' }
unless target
  target = project.new_target(
    :command_line_tool,
    'DHQClashNetworkExtension',
    :osx,
    '11.0',
  )
  target.product_type = 'com.apple.product-type.system-extension'
  target.product_reference.path = 'app.dhqclash.network-extension.systemextension'
  target.product_reference.explicit_file_type = 'wrapper.system-extension'
end

network_extension_group =
  project.main_group.find_subpath('NetworkExtension', true)
network_extension_group.set_source_tree('<group>')
network_extension_group.set_path('NetworkExtension')

source_names = %w[
  main.swift
  TransparentProxyProvider.swift
  Socks5TCPRelay.swift
]
source_names.each do |name|
  ref = network_extension_group.files.find { |file| file.path == name }
  ref ||= network_extension_group.new_file(name)
  target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
end

%w[Info.plist Debug.entitlements Release.entitlements].each do |name|
  next if network_extension_group.files.any? { |file| file.path == name }

  network_extension_group.new_file(name)
end

runner_group = project.main_group['Runner']
plugin_ref =
  runner_group.files.find { |file| file.path == 'MacosTunPlugin.swift' } ||
  runner_group.new_file('MacosTunPlugin.swift')
unless runner.source_build_phase.files_references.include?(plugin_ref)
  runner.add_file_references([plugin_ref])
end

frameworks = {
  'NetworkExtension.framework' =>
    'System/Library/Frameworks/NetworkExtension.framework',
  'SystemExtensions.framework' =>
    'System/Library/Frameworks/SystemExtensions.framework',
}
frameworks.each do |name, path|
  ref =
    project.frameworks_group.files.find { |file| file.path == path } ||
    project.frameworks_group.new_file(path)
  target.frameworks_build_phase.add_file_reference(ref) if name == 'NetworkExtension.framework' &&
    !target.frameworks_build_phase.files_references.include?(ref)
  runner.frameworks_build_phase.add_file_reference(ref) unless
    runner.frameworks_build_phase.files_references.include?(ref)
end

target.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['CODE_SIGN_ENTITLEMENTS'] =
    configuration.name == 'Debug' ?
      'NetworkExtension/Debug.entitlements' :
      'NetworkExtension/Release.entitlements'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  settings['DEAD_CODE_STRIPPING'] = 'YES'
  settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['INFOPLIST_FILE'] = 'NetworkExtension/Info.plist'
  settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
  settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  # Runner's project-level CocoaPods flags link every Flutter plugin. The
  # isolated system extension only links its own NetworkExtension framework.
  settings['OTHER_LDFLAGS'] = ''
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'app.dhqclash.network-extension'
  settings['PRODUCT_NAME'] = 'app.dhqclash.network-extension'
  settings['SKIP_INSTALL'] = 'YES'
  settings['SWIFT_VERSION'] = '5.0'
end

unless runner.dependencies.any? { |dependency| dependency.target == target }
  runner.add_dependency(target)
end

embed_phase =
  runner.copy_files_build_phases.find {
    |phase| phase.name == 'Embed System Extensions'
  }
unless embed_phase
  embed_phase = runner.new_copy_files_build_phase('Embed System Extensions')
end
embed_phase.dst_subfolder_spec = '16'
embed_phase.dst_path = '$(SYSTEM_EXTENSIONS_FOLDER_PATH)'
unless embed_phase.files_references.include?(target.product_reference)
  build_file = embed_phase.add_file_reference(target.product_reference)
  build_file.settings = {
    'ATTRIBUTES' => %w[CodeSignOnCopy RemoveHeadersOnCopy],
  }
end

attributes = project.root_object.attributes['TargetAttributes'] ||= {}
attributes[target.uuid] ||= {
  'CreatedOnToolsVersion' => '16.0',
  'ProvisioningStyle' => 'Automatic',
}

project.save
