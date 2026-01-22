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

- [ ] agree on `try/catch` and `done()`;
- [ ] the return "" is untested on the LineOrCap wipe spell;
- [ ] there are some untested descriptions and catches all over the repo, decide if we want to address them here; 
- [ ] decide if `done` name should be changed, since it does not perform a real "done" check.
