require 'sinatra'
require 'yaml'
require 'json'
require 'curb'
require 'erubis'

begin
    # local
    config = YAML::load(Erubis::Eruby.new(File.open('config.yml').read).result)
rescue
    # heroku
    config = YAML::load(Erubis::Eruby.new(File.open('config.yml.heroku').read).result)
end

set :sessions, true
set :logging, true
set :port, 3000
set :gh_user, config['user']
set :gh_pass, config['pass']
set :gh_token, config['token']
set :gh_api, "https://api.github.com/"
set :gh_issue, "repos/:owner/:repo/issues/:number/labels" # get
set :gh_add_label, "repos/:owner/:repo/issues/:number/labels" # post
set :gh_remove_label, "repos/:owner/:repo/issues/:number/labels/:name" # delete
set :gh_update_label, "repos/:owner/:repo/issues/:number/labels" # put
set :gh_edit_issue, "repos/:owner/:repo/issues/:number" # patch


def get_labels(user, repo, issue)
    endpoint = settings.gh_issue.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    curl = Curl::Easy.http_get(settings.gh_api + endpoint + '?access_token=' + settings.gh_token) do |c|
        c.http_auth_types = :basic
        c.username = settings.gh_user
        c.password = settings.gh_pass
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    json = JSON.parse(curl.body_str)
    json['issue']['labels']
end

def add_labels(user, repo, issue, label)
    endpoint = settings.gh_add_label.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    begin
        Curl::Easy.http_post(settings.gh_api + endpoint + '?access_token=' + settings.gh_token, label) do |c|
            c.http_auth_types = :basic
            c.username = settings.gh_user
            c.password = settings.gh_pass
            c.headers['User-Agent'] = 'Github-Issuehooks'
        end
        p 'added label(s)'
    rescue e
        p e.to_s
    end
end

def remove_label(user, repo, issue, label)
    endpoint = settings.gh_remove_label.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue).gsub(':name', label)
    Curl::Easy.http_delete(settings.gh_api + endpoint + '?access_token=' + settings.gh_token) do |c|
        c.http_auth_types = :basic
        c.username = settings.gh_user
        c.password = settings.gh_pass
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    p 'removed label(s)'
end

def update_labels(user, repo, issue, label)
    endpoint = settings.gh_update_label.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    Curl::Easy.http_put(settings.gh_api + endpoint + '?access_token=' + settings.gh_token, label) do |c|
        c.http_auth_types = :basic
        c.username = settings.gh_user
        c.password = settings.gh_pass
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    p 'updated labels'
end

def assign_issue(user, repo, issue, assignee)
    p 'debug'
    p settings
    p 'others'
    p settings.gh_edit_issue
    p user
    p repo
    p issue
    p settings.gh_api
    p endpoint
    p settings.gh_token
    p assignee
    endpoint = settings.gh_edit_issue.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    Curl.patch(settings.gh_api + endpoint + '?access_token=' + settings.gh_token, {:assignee => assignee}.to_json) do |c|
        c.http_auth_types = :basic
        c.username = settings.gh_user
        c.password = settings.gh_pass
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    p 'assigned issue to ' + assignee
end

def assign_milestone(user, repo, issue, milestone)
    endpoint = settings.gh_edit_issue.gsub(':owner', user).gsub(':repo', repo).gsub(':number', issue)
    Curl.patch(settings.gh_api + endpoint + '?access_token=' + settings.gh_token, {:milestone => milestone}.to_json) do |c|
        c.http_auth_types = :basic
        c.username = settings.gh_user
        c.password = settings.gh_pass
        c.headers['User-Agent'] = 'Github-Issuehooks'
    end
    p 'assigned new milestone'
end

get '/test' do
  p 'hello world'
end

post '/' do
    request.body.rewind
    json = request.body.read.to_s
    push = json && json.length >= 2 ? JSON.parse(json) : nil
    repo = push['repository']['name']
    owner = push['repository']['owner']['name']
    push['commits'].each do |c|
        m = c['message']
        issue = m.scan(/\#[0-9]+/)
        if issue.size == 1 #only check for other goodies if an issue is mentioned
            
            # user assignment
            user = m.scan(/\=[a-zA-Z0-9\-]+/)[0] # hyphens and alphanumerics are allowed in github usernames
            assign_issue(owner, repo, issue[0], user[1..-1]) if user
            
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
            milestone = m.scan(/\^[0-9]+/)[0]
            assign_milestone(owner, repo, issue[0], milestone[1..-1]) if milestone
        end
    end
    status 200
    body ''
end
