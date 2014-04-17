# GitLab RT Linker

GitLab RT is a Ruby + Rack implementation of a simple daemon to communicate with RT about new commits.

Currently, it only will update the "Referred to by" link of a ticket to point back to any commits that reference that ticket.

## Install

To install for deployment, be sure to have the `bundler` gem installed, and then you can do:

    RUBY=/path/to/ruby
    $RUBY/bin/bundle install --deployment --binstubs --shebang $RUBY/bin/ruby

You will also need to create a `config.rb` file for your environment.  There is an example provided.
