require_relative '../test_helper'

describe GitRepository, :model do

  let(:repository_url) { Dir.mktmpdir }
  let(:project) { Project.new(id: 99999, name: 'test_project', repository_url: repository_url) }
  let(:repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }

  it 'checks that the project repository is pointing to the correct url and directory' do
    repo = project.repository
    repo.is_a? GitRepository
    repo.repository_url.must_equal project.repository_url
    repo.repository_directory.must_equal project.repository_directory
  end

  after(:each) do
    FileUtils.rm_rf(repository_url)
    FileUtils.rm_rf(repo_dir)
    FileUtils.rm_rf(project.repository.repo_cache_dir)
  end

  it 'should clone a repository' do
    Dir.mktmpdir do |dir|
      create_repo_with_tags
      project.repository.clone!(from: repository_url, to: dir)
      Dir.exist?(dir).must_equal true
    end
  end

  it 'should update the repository' do
    create_repo_with_tags
    project.repository.clone!.must_equal(true)
    Dir.chdir(project.repository.repo_cache_dir) { number_of_commits.must_equal(1) }
    execute_on_remote_repo <<-SHELL
      echo monkey > foo2
      git add foo2
      git commit -m "second commit"
    SHELL
    project.repository.update!.must_equal(true)
    Dir.chdir(project.repository.repo_cache_dir) do
      update_workspace
      number_of_commits.must_equal(2)
    end
  end

  it 'should switch to a different branch' do
    create_repo_with_an_additional_branch
    project.repository.clone!.must_equal(true)
    project.repository.checkout!(git_reference: 'master').must_equal(true)
    Dir.chdir(project.repository.repo_cache_dir) { current_branch.must_equal('master') }
    project.repository.checkout!(git_reference: 'test_user/test_branch').must_equal(true)
    Dir.chdir(project.repository.repo_cache_dir) { current_branch.must_equal('test_user/test_branch') }
  end

  it 'returns the tags repository' do
    create_repo_with_tags
    project.repository.clone!(executor: TerminalExecutor.new(StringIO.new), mirror: true)
    project.repository.tags.to_a.must_equal %w(v1 )
  end

  it 'returns an empty set of tags' do
    create_repo_without_tags
    project.repository.clone!(executor: TerminalExecutor.new(StringIO.new), mirror: true)
    project.repository.tags.must_equal []
  end

  it 'returns the branches of the repository' do
    create_repo_with_an_additional_branch
    project.repository.clone!(executor: TerminalExecutor.new(StringIO.new), mirror: true)
    project.repository.branches.to_a.must_equal %w(master test_user/test_branch)
  end

  it 'sets the repository to the provided git reference' do
    create_repo_with_an_additional_branch
    executor = TerminalExecutor.new(StringIO.new)
    temp_dir = Dir.mktmpdir
    project.repository.clone!(executor: executor, mirror: true)
    project.repository.setup!(executor, temp_dir, 'test_user/test_branch').must_equal(true)
    Dir.chdir(temp_dir) { current_branch.must_equal('test_user/test_branch') }
  end

  it 'validates the repo url' do
    create_repo_without_tags
    project.repository.valid_url?.must_equal true
  end

  it 'invalidates the repo url without repo' do
    project.repository.valid_url?.must_equal false
  end

  def execute_on_remote_repo(cmds)
    `exec 2> /dev/null; cd #{repository_url}; #{cmds}`
  end

  def create_repo_with_tags
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
      git tag v1
    SHELL
  end

  def create_repo_without_tags
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
    SHELL
  end

  def create_repo_with_an_additional_branch
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo monkey > foo
      git add foo
      git commit -m "initial commit"

      git checkout -b test_user/test_branch
      echo monkey > foo2
      git add foo2
      git commit -m "branch commit"
      git checkout master
    SHELL
  end

  def current_branch
    `git rev-parse --abbrev-ref HEAD`.strip
  end

  def number_of_commits
    `git rev-list HEAD --count`.strip.to_i
  end

  def update_workspace
    `git pull`.strip
  end

end
