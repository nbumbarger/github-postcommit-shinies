# Getting started
Move config.yml.sample to config.yml and enter your details

Start sinatra and point your repo's hook to the sinatra ip/port!

# What can this do?

* Add / remove / toggle labels
* Reassign to a different user
* Change the milestone
* (Future) Change the [Zenhub](http://zenhub.io) pipeline

# How to assign a user

To assign a user, simply use `=` before their username. This will assign it to them. To reference the user *without* assigning it, use `@` like normal. (This creates a link to their github page)

    git commit -m "unicorns are awesome. @bossman be advised I'm giving this to =yoshokatana"

# How to change milestone

Currently milestones are referenced by their number (rather than a name or slug), so only use this if you know what you're doing.
    
    git commit -m "unicorns are not going to be ready for this release. pushing to ^2"

# How to add, remove, and toggle labels   

## Adding

Adding simply uses the plus sign. You can also add labels with spaces in them by quoting them
    
    git commit -m "issue #26 unicorns are awesome +unicorns +'too cool for school'"

## Removing

Removing labels uses the minus sign (hyphen). You can also use quotes.

    git commit -m "#26 unicorns aren't so awesome anymore -unicorns -'too cool for school'"

## Toggling

If you're super lazy (I am!), you can simply use `~` to toggle labels on or off. I wouldn't recommend using this all the time, but it's useful if you have certain labels you use for statuses.

    git commit -m "finally finished integrating unicorns into #26 ~resolved"

# Mix and match!
    
    git commit -m "this actually +resolved issue #26 to we can add it to the ^1 release, reassigning to =yoshokatana for review."

# Future: How to change a pipeline

I'm going to chat with the zenhub people and see if there's a programmatic way to change pipelines. The command will probably look like this. The number after the pipe character references the board's position (e.g. for Icebox, Backlog, Current Sprint, QA, `|4` would be QA).

    git commit -m "#26 is ready for QA testing |4"