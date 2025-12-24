# StUSDS Emergency Spells

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