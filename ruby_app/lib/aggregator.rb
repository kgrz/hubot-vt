class Aggregator
  attr_reader :client, :repo, :pulls, :aggregated_data, :pull_data

  GH_AUTH_TOKEN        = ENV["GH_AUTH_TOKEN"]
  HUBOT_VT_GITHUB_ORG  = ENV["HUBOT_VT_GITHUB_ORG"]
  HUBOT_VT_GITHUB_REPO = ENV["HUBOT_VT_GITHUB_REPO"]

  def initialize
    @client = Octokit::Client.new access_token: GH_AUTH_TOKEN
    @repo   = client.repo "#{HUBOT_VT_GITHUB_ORG}/#{HUBOT_VT_GITHUB_REPO}"

    get_pulls!
    get_individual_open_pull_data!
  end

  def open_pulls
    pulls.select { |x| x[:state] = "open" }
  end

  def mergeable_pulls
    aggregated_data.select { |x| x[:mergeable] == true }
  end

  # We are relying on the assumption that the :mergeable key has true, false or
  # "Unspecified" as possible values. If we just do !!x[:mergeable], it will
  # not work.
  def unmergeable_pulls
    aggregated_data.select { |x| x[:mergeable] != true }
  end

  def aggregated_data
    @aggregated_data ||=
      pull_data.map do |pull|
        assignee = pull[:assignee] ? pull[:assignee][:login] : "Not assigned"
        {
          title:      pull[:title],
          mergeable:  pull[:mergeable] || "Unspecified",
          assignee:   assignee,
          number:     pull[:number],
          opened_by:  pull[:user][:login],
          html_url:   pull[:html_url],
          created_at: pull[:created_at]
        }
      end
  end

  def all_stats
    AllStats.new(self)
  end

  def conflict_stats
    ConflictStats.new(self)
  end

  def user_stats(user)
    UserStats.new(self, user)
  end

  private

  def get_pulls!
    @pulls ||= repo.rels[:pulls].get.data
  end

  def get_individual_open_pull_data!
    @pull_data ||=
      open_pulls.map do |pull|
        pull.rels[:self].get.data
      end
  end
end
