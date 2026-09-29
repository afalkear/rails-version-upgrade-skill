require "minitest/autorun"
require "yaml"
require "rubygems"

class VersionGraphTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  GRAPH = YAML.safe_load(File.read(File.join(ROOT, "data/rails_versions.yml"))).fetch("rails_versions")

  def path(current, target)
    result = [current]
    until current == target
      current = GRAPH.fetch(current).fetch("next")
      raise "Unreachable target #{target}" unless current
      raise "Cycle at #{current}" if result.include?(current)
      result << current
    end
    result
  end

  def required_ruby(current)
    node = GRAPH.fetch(current)
    node.fetch("target_ruby_min") { GRAPH.fetch(node.fetch("next")).fetch("ruby_min") }
  end

  def test_requested_single_hops
    {"7.0" => "7.1", "7.2" => "8.0", "8.0" => "8.1"}.each do |current, target|
      assert_equal [current, target], path(current, target)
    end
  end

  def test_every_node_reaches_the_terminal_version_without_cycles
    GRAPH.each_key { |version| assert_equal "8.1", path(version, "8.1").last }
  end

  def test_ruby_gate_uses_the_destination_requirement
    {"7.0" => "2.7.0", "7.2" => "3.2.0", "8.0" => "3.2.0"}.each do |version, minimum|
      assert_equal minimum, required_ruby(version)
    end
  end

  def test_sample_application_preflights
    # Rails minor, application Ruby, whether the next hop passes the Ruby gate.
    [["7.0", "3.1.2", true], ["7.2", "3.1.0", false],
     ["7.2", "3.3.11", true], ["8.0", "3.2.11", true],
     ["8.0", "4.0.1", true]].each do |current, ruby, eligible|
      assert_equal eligible, Gem::Version.new(ruby) >= Gem::Version.new(required_ruby(current))
    end
  end

  def test_guide_files_and_heading_anchors_resolve
    GRAPH.each_value do |node|
      file, anchor = node.fetch("guide").split("#", 2)
      filename = File.join(ROOT, file)
      assert File.file?(filename), "Missing #{file}"
      next unless anchor
      headings = File.read(filename).lines.grep(/^#+ /).map do |line|
        line.sub(/^#+ /, "").strip.downcase.gsub(/[^\p{L}\p{N}\- _]/, "").tr(" ", "-")
      end
      assert_includes headings, anchor, "Missing #{file}##{anchor}"
    end
  end

  def test_unknown_versions_are_not_silently_skipped
    assert_raises(KeyError) { path("6.2", "7.0") }
    assert_raises(RuntimeError) { path("8.0", "8.2") }
  end

  def test_skill_frontmatter_and_required_resources
    skill = File.read(File.join(ROOT, "SKILL.md"))
    frontmatter = YAML.safe_load(skill.split("---", 3).fetch(1))
    assert_equal "rails-version-upgrade", frontmatter.fetch("name")
    assert_match(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, frontmatter.fetch("name"))
    assert_operator frontmatter.fetch("description").length, :<=, 1024
    refute_empty frontmatter.fetch("description").strip
    skill.scan(/`((?:data|references|maintainers)\/[^`]+)`/).flatten.each do |resource|
      assert File.file?(File.join(ROOT, resource)), "Missing packaged resource #{resource}"
    end
  end
end
