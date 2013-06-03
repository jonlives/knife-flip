# knife-flip

A knife plugin to move a node, or all nodes in a role, to a specific environment

## SCRIPT INSTALL

Copy *.rb script from lib/chef/knife to your ~/.chef/plugins/knife directory.

## GEM INSTALL
knife-flip is available on rubygems.org - if you have that source in your gemrc, you can simply use:

````
gem install knife-flip
````

## What it does

````
knife node flip mynode.foo.com myenv [--preview]
````

will move the node mynode.foo.com into the environment myenv. Passing in the --preview option
it will dry-run the flip and show you what cookbooks and versions would be applied if it were actually
flipped.


````
knife role flip MyRole myenv
````

will move all nodes containing the role MyRole in their runlists into the environment myenv