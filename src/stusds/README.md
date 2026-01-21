# StUSDS Emergency Spells

## Informations

### SingleLineOrCapWipeSpell.sol

Contract that can be used to deploy 3 different spells:

* Only Line wipe;
* Only Cap wipe;
* Both Line and Cap wipe;

Alternatively, we can build 3 different contracts separately, the pro would be to save a little more gas not having to deal with different patterns and focus on implementing only the needed option: `StUsdsCapWipeSpell.sol`, `StUsdsLineWipeSpell.sol` and `StUsdsLineAndCapWipeSpell.sol`.

### DissRateSetterBudFactory

1. deploy spell for each bud;
2. have the factory ready for the newer buds.



## ToDo

- [ ] Agree if all the wards checks are necessary in `done()`:
    * [ ] stUsds -> stUsdsMom;
    * [ ] stUsds -> stUsdsRateSetter;
    * [ ] stUsdsRateSetter -> stUsdsMom;
- [ ] decide if use the `SingleLineOrCapWipeSpell.sol` (`SingleLitePsmHaltSpell.sol` approach) for line and cap to 0 or if it's better to go with single contracts per each parameter (`StUsdsLineWipeSpell.sol` and `StUsdsCapWipeSpell.sol`);
- [ ] check if it is preferred to initialize the contracts (`stUsds`, `stUsdsMom` and `stUsdsRateSetter`) from constructor; or should be directly fetched from the chainlog by the spell;
  - [ ] STUSDS;
  - [ ] STUSDS_MOM;
  - [ ] STUSDS_RATE_SETTER;
- [ ] agree if the `description()` should be pure or maybe should log even the contract addresses;
- [ ] agree on `try/catch` in testing, expand it to the parameter query like `line`, `maxLine`, and the rest.
- 