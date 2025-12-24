# StUSDS emergency spells

## ToDo

- [ ] Agree if all the wards checks are necessary in `done()`:
    * [ ] stUsds -> stUsdsMom;
    * [ ] stUsds -> stUsdsRateSetter;
    * [ ] stUsdsRateSetter -> stUsdsMom;
- [ ] decide if use the LitePsmHalt approach for line and cap to 0 or if it's better to go with single contracts per each parameter;
    * SingleSpell has more clear events name for instance;
- [ ] check if it is preferred to initialize the contracts (stUsds, stUsdsMom and stUsdsRateSetter) from outside - in the constructor - or should be directly fetched from the chainlog from the spell itself;
  - [ ] STUSDS;
  - [ ] STUSDS_MOM;
  - [ ] STUSDS_RATE_SETTER;
- [ ] agree if the `description()` should be pure or maybe should log even the contract addresses;
- [ ] agree on `try/catch` in testing, expand it to the parameter query like `line`, `maxLine`, etc..;