require 'minitest_helper'
require "tmpdir"
require "pre-commit/cli"

describe "integration" do
  it "prevents bad commits" do
    in_git_dir do
      result = commit_a_file :fail => true
      assert_includes result, "detected tab before initial"
      assert_includes result, "new blank line at EOF"
      assert_includes result, "You can bypass this check using"
    end
  end

  it "bypasses pre-commit checks when using the no-verify option" do
    in_git_dir do
      result = commit_a_file :no_check => true
      refute_includes result, "detected tab before initial"
      assert_includes result, "create mode 100644 xxx.rb"
    end
  end

  it "does not prevent bad commits when checks are disabled" do
    in_git_dir do
      sh "git config 'pre-commit.checks' 'jshint'"
      result = commit_a_file
      refute_includes result, "detected tab before initial"
      assert_includes result, "create mode 100644 xxx.rb"
    end
  end

  it "prevents bad commits when certain checks are enabled" do
    in_git_dir do
      sh "git config 'pre-commit.checks' 'tabs'"
      result = commit_a_file :fail => true
      assert_includes result, "detected tab before initial"
      refute_includes result, "new blank line at EOF"
      assert_includes result, "You can bypass this check using"
    end
  end

  it "can overwrite existing hook" do
    write ".git/hooks/pre-commit", "XXX"
    sh "ruby -I #{project_dir}/lib #{project_dir}/bin/pre-commit install"
    read(".git/hooks/pre-commit").must_include "pre-commit"
  end

  describe "local checks" do
    it "prevents bad commits when local checks fail" do
      in_git_dir do
        write("config/pre-commit.rb", "raise 'FOOO'")
        result = commit_a_file :content => "XXX", :fail => true
        assert_includes result, "FOOO"
      end
    end

    it "allows good commits when local checks succeed" do
      in_git_dir do
        write("config/pre-commit.rb", "")
        result = commit_a_file :content => "XXX"
        assert_includes result, "create mode 100644 xxx.rb"
      end
    end
  end

  def in_git_dir(&block)
    Dir.mktmpdir(nil, ENV['TMPDIR'] || '/tmp') do |dir|
      Dir.chdir(dir) do
        sh "git init"
        sh "git config pre-commit.ruby 'ruby #{ruby_includes}'"
        install
        yield
      end
    end
  end

  def commit_a_file(options={})
    write("xxx.rb", options[:content] || "\t\tMuahaha\n\n\n")
    sh "git add -A"
    sh("git commit #{options[:no_check] ? "-n" : ""} -m 'EVIL'", options)
  end

  def sh(command, options={})
    result = `#{command} 2>&1`
    raise "FAILED #{command}\n#{result}" if $?.success? == !!options[:fail]
    result
  end

  def install
    sh "ruby -I #{project_dir}/lib #{project_dir}/bin/pre-commit install"
    assert File.exist?(".git/hooks/pre-commit"), "The hook file does not exist"
    assert File.executable?(".git/hooks/pre-commit"), "The hook file is not executable"
    sh "git commit -m Initial --allow-empty" # or travis fails with: No HEAD commit to compare with
  end

  def ensure_folder(folder)
    FileUtils.mkdir_p(folder) unless File.exist?(folder)
  end

  def write(file, content)
    ensure_folder File.dirname(file)
    File.open(file, 'w'){|f| f.write content }
  end

  def read(file)
    File.read file
  end
end
