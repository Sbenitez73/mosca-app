#!/usr/bin/env ruby
# Configures the Xcode project for Mosca:
#   1. Adds MoscaAppIntents.swift to Runner Sources
#   2. Creates MoscaWidget extension target (small + medium home screen widget)
#   3. Wires up App Groups entitlements on both targets
#   4. Embeds the widget extension into Runner

require 'xcodeproj'
require 'securerandom'

PROJECT_PATH   = File.join(__dir__, 'Runner.xcodeproj')
WIDGET_DIR     = File.join(__dir__, 'MoscaWidget')
RUNNER_DIR     = File.join(__dir__, 'Runner')
TEAM_ID        = 'H8C9L4RHHV'
BUNDLE_ID      = 'com.mosca.mosca'
WIDGET_BUNDLE  = 'com.mosca.mosca.MoscaWidget'
APP_GROUP      = 'group.com.mosca.mosca'

project = Xcodeproj::Project.open(PROJECT_PATH)

runner_target = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless runner_target

# ── 1. Add MoscaAppIntents.swift to Runner Sources ───────────────────────────
runner_group = project.main_group.find_subpath('Runner', false)
intents_path = File.join(RUNNER_DIR, 'MoscaAppIntents.swift')

unless runner_group.files.any? { |f| f.path == 'MoscaAppIntents.swift' }
  intents_ref = runner_group.new_file(intents_path)
  intents_ref.set_source_tree('<group>')
  intents_ref.set_path('MoscaAppIntents.swift')
  sources_phase = runner_target.build_phases.find { |p| p.is_a?(Xcodeproj::Project::Object::PBXSourcesBuildPhase) }
  sources_phase.add_file_reference(intents_ref)
  puts '  [ok] Added MoscaAppIntents.swift to Runner Sources'
else
  puts '  [skip] MoscaAppIntents.swift already in project'
end

# ── 2. Add Runner.entitlements to Runner build settings ──────────────────────
entitlements_rel = 'Runner/Runner.entitlements'
runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_rel
end
puts '  [ok] Wired Runner.entitlements'

# ── 3. Create MoscaWidget target ─────────────────────────────────────────────
if project.targets.any? { |t| t.name == 'MoscaWidget' }
  puts '  [skip] MoscaWidget target already exists'
else
  widget_target = project.new_target(
    :app_extension,
    'MoscaWidget',
    :ios,
    '16.0',
    nil,
    :swift
  )

  # Build settings common to all configurations
  base_settings = {
    'PRODUCT_BUNDLE_IDENTIFIER'      => WIDGET_BUNDLE,
    'DEVELOPMENT_TEAM'               => TEAM_ID,
    'SWIFT_VERSION'                  => '5.0',
    'TARGETED_DEVICE_FAMILY'         => '1,2',
    'IPHONEOS_DEPLOYMENT_TARGET'     => '16.0',
    'INFOPLIST_FILE'                 => 'MoscaWidget/Info.plist',
    'CODE_SIGN_ENTITLEMENTS'         => 'MoscaWidget/MoscaWidget.entitlements',
    'CODE_SIGN_STYLE'                => 'Automatic',
    'SKIP_INSTALL'                   => 'YES',
  }

  widget_target.build_configurations.each do |config|
    config.build_settings.merge!(base_settings)
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] =
      config.name == 'Debug' ? '-Onone' : '-O'
  end

  # Add source file reference in a new MoscaWidget group
  widget_group = project.main_group.new_group('MoscaWidget', 'MoscaWidget')
  swift_file   = widget_group.new_file(File.join(WIDGET_DIR, 'MoscaWidget.swift'))
  swift_file.set_source_tree('<group>')
  swift_file.set_path('MoscaWidget.swift')

  widget_target.source_build_phase.add_file_reference(swift_file)
  puts '  [ok] Created MoscaWidget target'

  # ── 4. Embed widget into Runner ─────────────────────────────────────────────
  embed_phase = runner_target.build_phases.find do |p|
    p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
      p.name == 'Embed App Extensions'
  end

  unless embed_phase
    embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    embed_phase.name          = 'Embed App Extensions'
    embed_phase.dst_subfolder_spec = '13' # PlugIns
    embed_phase.dst_path      = ''
    runner_target.build_phases << embed_phase
  end

  # Add the widget product to Products group and embed phase
  widget_product_ref = widget_target.product_reference
  embed_build_file   = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  embed_build_file.file_ref = widget_product_ref
  embed_build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  embed_phase.files << embed_build_file

  # Add widget target as dependency of Runner
  dep = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
  dep.target = widget_target
  runner_target.dependencies << dep

  puts '  [ok] Embedded MoscaWidget into Runner'
end

project.save
puts "\nproject.pbxproj saved — all done!"
