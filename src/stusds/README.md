# StUSDS Emergency Spells

## Contracts

### SingleLineOrCapWipeSpell.sol

Contract that can be used to deploy 3 different spells:

* Only Line wipe;
* Only Cap wipe;
* Both Line and Cap wipe;

### DissRateSetterBud

1. deploy the emergency spell for each `bud`;
2. have the factory ready for the newer buds.

### HaltRateSetterBudFactory

Single Contract to halt the StUsdsRateSetter, by calling the `bad()` method.

## ToDo

- [ ] agree on `try/catch` in testing
- [ ] the return "" is untested on the LineOrCap wipe
- [ ] there are some untested descriptions all over the repo. 
- [ ]      // todo: decided that done would be using this new design, so it's not just "done" but more a "can this be run", so we need to comply?
     // todo: the name is bad, canBeExected? 
