require 'sinatra'
require 'yaml'
require 'json'
require 'curb'
require 'erubis'

begin
    config = YAML::load(Erubis::Eruby.new(File.open('config.yml').read).result)
rescue
    config = YAML::load(Erubis::Eruby.new(File.open('config.yml.heroku_sample').read).result)
end

set :sessions, true
set :logging, true
set :port, 3000
set :gh_user, config['user']
set :gh_token, config['token']
set :gh_api, "https://api.github.com/"
set :gh_issue, "repos/:owner/:repo/issues/:number/labels" # get
set :gh_add_label, "repos/:owner/:repo/issues/:number/labels" # post
set :gh_remove_label, "repos/:owner/:repo/issues/:number/labels/:name" # delete
set :gh_update_label, "repos/:owner/:repo/issues/:number/labels" # put
set :gh_edit_issue, "repos/:owner/:repo/issues/:number"


def get_labels(user, repo, issue)
    endpoint = options.gh_issue.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    curl = Curl::Easy.http_get(options.gh_api + endpoint) do |c|
        c.http_auth_types = :basic
        c.username = options.gh_user
        c.password = options.gh_token
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    json = JSON.parse(curl.body_str)
    json['issue']['labels']
end

def add_labels(user, repo, issue, label)
    endpoint = options.gh_add_label.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    curl = Curl::Easy.http_post(options.gh_api + endpoint, label) do |c|
        c.http_auth_types = :basic
        c.username = options.gh_user
        c.password = options.gh_token
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    p curl.body_str
end

def remove_label(user, repo, issue, label)
    endpoint = options.gh_remove_label.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue).gsub(':name', label)
    curl = Curl::Easy.http_delete(options.gh_api + endpoint) do |c|
        c.http_auth_types = :basic
        c.username = options.gh_user
        c.password = options.gh_token
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    p curl.body_str
end

def update_labels(user, repo, issue, label)
    endpoint = options.gh_update_label.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    curl = Curl::Easy.http_put(options.gh_api + endpoint, label) do |c|
        c.http_auth_types = :basic
        c.username = options.gh_user
        c.password = options.gh_token
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    p curl.body_str
end

def assign_issue(user, repo, issue, assignee)
    endpoint = options.gh_edit_issue.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    curl = Curl::Easy.http_patch(options.gh_api + endpoint, {:assignee => assignee}.to_json) do |c|
        c.http_auth_types = :basic
        c.username = options.gh_user
        c.password = options.gh_token
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    p curl.body_str
end

def assign_milestone(user, repo, issue, milestone)
    endpoint = options.gh_edit_issue.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    curl = Curl::Easy.http_patch(options.gh_api + endpoint, {:milestone => milestone}.to_json) do |c|
        c.http_auth_types = :basic
        c.username = options.gh_user
        c.password = options.gh_token
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    p curl.body_str
end

get '/test' do
  p 'hello world'
end

post '/' do
    push = JSON.parse(request.body.read)
    repo = push['repository']['name']
    owner = push['repository']['owner']['name']
    push['commits'].each do |c|
        m = c['message']
        issue = m.scan(/\#[0-9]+/)
        if issue.size == 1 #only check for other goodies if an issue is mentioned
            
            # user assignment
            begin
                user = m.scan(/\=[a-zA-Z0-9]+/)[0].split(//)[1..-1].join
                assign_issue(owner, repo, issue[0], user)
            rescue => e
              p e.to_s
            end
            
            # label toggles
            label_toggles = m.scan(/\~[a-zA-Z0-9]+|\~".*?"|\~'.*?'/)
            if label_toggles.size > 0
                current_labels = get_labels()

                label_toggles.map { |s| s[1..-1] } # remove beginning ~

                label_toggles.reject { |l| current_labels.any? { |x| x[:name] == l } } # remove strings from label_toggles that match the name of any hash in current_labels

                update_label(owner, repo, issue[0], label_toggles)
            end

            # label adding
            label_additions = m.scan(/\+[a-zA-Z0-9]+|\+".*?"|\+'.*?'/)
            if label_additions.size > 0
                add_labels(owner, repo, issue[0], label_additions)
            end

            # label removing
            label_deletions = m.scan(/\-[a-zA-Z0-9]+|\-".*?"|\-'.*?'/)
            if label_deletions.size > 0
                remove_labels(owner, repo, issue[0], label_deletions)
            end

            # milestone assignment
            begin
                milestone = m.scan(/\^[a-zA-Z0-9]+/)[0].split(//)[1..-1].join
                assign_milestone(owner, repo, issue[0], milestone)
            rescue => e
              p e.to_s
            end
        end
    end
end
