# knife-flip

A knife plugin to move a node, or all nodes in a role, to a specific environment

## What it does

````
knife node flip mynode.foo.com myenv
````

will move the node mynode.foo.com into the environment myenv


````
knife role flip MyRole myenv
````

will move all nodes containing the role MyRole in their expanded runlists into the environment myenv