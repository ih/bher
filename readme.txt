There are two example files that use the with-proposer tag.  They can be run with the following commands from the root directory of bher

> bher grammar.church
and
> bher testing/with-proposer-tests.church

I've moved external library files I was using into the root directory of bher so hopefully everything should just run when you clone this repository (there's probably a better way to do this without cluttering the root directory, but this should be a temporary fix).  The only thing you might need is srfi 13 which can be downloaded from https://code.launchpad.net/~scheme-libraries-team/scheme-libraries/srfi


===============
changes from the way original bher works

MCMC-PREAMBLE.CHURCH
basic-proposal-distribution - rewritten to choose between using original xrp proposals or with-proposer proposals

smc-core - can take an initial address used when a with-proposer proposal is being made, important for getting random choices of a proposed state 

mh-expr-query - allows one to specify an initial expression as the starting state when the generative model is a grammar

HEADER.SS
make-store - added a field for with-proposer-calls, a with-proposer-call is similar to a xrp-draw

church-with-proposer - creates a function that "replaces" the procedure with-proposer is attached to.  it calls the procedure and does some additional book-keeping, it's similar to church-make-xrp

=================


